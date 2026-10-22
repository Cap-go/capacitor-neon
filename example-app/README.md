# Example App for `@capgo/capacitor-neon`

This Vite project links directly to the local plugin source so you can exercise the native APIs while developing.

## Actions in this playground

- **Initialize**: Initialize the Neon client with your branch's Auth and Data API URLs.
- **Sign in with password**: Sign in with email and password.
- **Sign up**: Sign up a new user with email and password.
- **Get anonymous token**: Get a Data API token for signed-out users.
- **Sign in with OAuth**: Sign in with an OAuth provider (opens external browser).
- **Sign in with OTP**: Send a one-time password to an email address.
- **Verify OTP**: Verify the one-time password received.
- **Get session**: Get the current session with JWT access token.
- **Get user**: Get the current authenticated user.
- **Refresh session**: Mint a new JWT for the current session.
- **Set session**: Restore a session from a refresh token.
- **Sign out**: Sign out the current user.
- **Select / Insert / Update / Delete (Database)**: Query a table through the Neon Data API.

Auth state changes appear under **Auth events**.

## Getting started

Copy `.env.example` to `.env` and fill in the URLs from the Neon Console so the Initialize form is prefilled.

```bash
bun install
bun run start
```

Add native shells with `bunx cap add ios` or `bunx cap add android` from this folder to try behaviour on device or simulator.

## Testing OAuth locally

Neon Auth only redirects to trusted http(s) URLs, so the app cannot receive the redirect on its custom scheme directly. Run the bounce page, which forwards the redirect to `com.capacitorneon.example://`:

```bash
bun run oauth-bounce
```

Then run **Sign in with OAuth** with the default redirect URL `http://localhost:8787/auth/callback`. On the Android emulator, run `adb reverse tcp:8787 tcp:8787` first so the emulator's localhost reaches your machine.
