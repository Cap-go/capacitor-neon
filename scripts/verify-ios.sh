#!/usr/bin/env bash
set -euo pipefail

pick_ios_simulator_destination() {
  python3 - <<'PY'
import json
import os
import subprocess

requested_runtime = os.environ.get("IOS_SIMULATOR_RUNTIME")
preferred_runtime = requested_runtime or "iOS-26"

result = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    check=True,
    capture_output=True,
    text=True,
)
data = json.loads(result.stdout)

preferred_names = [
    "iPhone 16",
    "iPhone 16 Pro",
    "iPhone 15",
    "iPhone 15 Pro",
    "iPhone 14",
    "iPhone SE (3rd generation)",
]


def collect_devices(runtime_filter: str) -> dict[str, str]:
    devices_by_name: dict[str, str] = {}
    for runtime, devices in data.get("devices", {}).items():
        if runtime_filter not in runtime or "Simulator" not in runtime:
            continue
        for device in devices:
            if not device.get("isAvailable"):
                continue
            name = device.get("name", "")
            if "iPhone" in name:
                devices_by_name[name] = device["udid"]
    return devices_by_name


def pick_from(devices_by_name: dict[str, str]) -> None:
    for preferred_name in preferred_names:
        if preferred_name in devices_by_name:
            print(f"platform=iOS Simulator,id={devices_by_name[preferred_name]}")
            raise SystemExit(0)

    if devices_by_name:
        _, udid = next(iter(devices_by_name.items()))
        print(f"platform=iOS Simulator,id={udid}")
        raise SystemExit(0)


runtime_filters = [preferred_runtime]
if not requested_runtime:
    runtime_filters.append("")

devices_by_name = collect_devices(preferred_runtime)
pick_from(devices_by_name)

if not requested_runtime:
    for runtime in sorted(data.get("devices", {}).keys(), reverse=True):
        if "Simulator" not in runtime or "iOS" not in runtime:
            continue
        devices_by_name = collect_devices(runtime)
        if devices_by_name:
            pick_from(devices_by_name)

raise SystemExit("No available iPhone simulator found for iOS tests.")
PY
}

destination="$(pick_ios_simulator_destination)"
echo "Running iOS unit tests on: ${destination}"

xcodebuild test \
  -scheme CapgoCapacitorNeon \
  -destination "${destination}" \
  -enableCodeCoverage NO
