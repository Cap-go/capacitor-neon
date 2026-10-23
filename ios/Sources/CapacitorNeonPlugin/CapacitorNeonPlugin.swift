import Foundation
import Capacitor

@objc(CapacitorNeonPlugin)
public class CapacitorNeonPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.1.0"
    public let identifier = "CapacitorNeonPlugin"
    public let jsName = "CapacitorNeon"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signInWithPassword", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signUp", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAnonymousToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signInWithOAuth", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signInWithOtp", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "verifyOtp", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signOut", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "refreshSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "select", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "insert", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "update", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "delete", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private var neonClient: NeonClient?
    private var pendingCallbackURL: URL?

    override public func load() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenURL(_:)), name: .capacitorOpenURL, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenURL(_:)), name: .capacitorOpenUniversalLink, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleOpenURL(_ notification: Notification) {
        guard let object = notification.object as? [String: Any], let url = object["url"] as? URL else { return }
        guard url.query?.contains(NeonClient.verifierParam) == true else { return }
        guard let client = neonClient else {
            // The app opened from the OAuth redirect before initialize() ran.
            pendingCallbackURL = url
            return
        }
        Task {
            _ = await client.handleCallback(url: url)
        }
    }

    @objc func initialize(_ call: CAPPluginCall) {
        guard let authUrlString = call.getString("authUrl"),
              let authUrl = URL(string: authUrlString.hasSuffix("/") ? String(authUrlString.dropLast()) : authUrlString) else {
            call.reject("Missing or invalid authUrl")
            return
        }
        let dataApiUrl = call.getString("dataApiUrl").flatMap { URL(string: $0) }
        let origin = call.getString("origin") ?? "https://localhost"

        let client = NeonClient(
            authURL: authUrl,
            dataApiURL: dataApiUrl,
            origin: origin,
            store: KeychainTokenStore()
        ) { [weak self] event, session in
            self?.notifyListeners(
                "authStateChange",
                data: ["event": event, "session": session ?? NSNull()],
                retainUntilConsumed: event == "INITIAL_SESSION"
            )
        }
        neonClient = client

        let pendingURL = pendingCallbackURL
        pendingCallbackURL = nil
        Task {
            await client.restore()
            if let pendingURL = pendingURL {
                _ = await client.handleCallback(url: pendingURL)
            }
            call.resolve()
        }
    }

    @objc func signInWithPassword(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let email = call.getString("email"),
              let password = call.getString("password") else {
            call.reject("Missing email or password")
            return
        }

        Task {
            do {
                call.resolve(try await client.signInWithPassword(email: email, password: password))
            } catch {
                call.reject("Sign in failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func signUp(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let email = call.getString("email"),
              let password = call.getString("password") else {
            call.reject("Missing email or password")
            return
        }

        let name = call.getString("name")
        let image = call.getString("image")

        Task {
            do {
                call.resolve(try await client.signUp(email: email, password: password, name: name, image: image))
            } catch {
                call.reject("Sign up failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func getAnonymousToken(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        Task {
            do {
                call.resolve(try await client.getAnonymousToken())
            } catch {
                call.reject("Anonymous token failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func signInWithOAuth(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let provider = call.getString("provider")?.lowercased(),
              ["google", "github", "vercel"].contains(provider) else {
            call.reject("Missing or invalid provider")
            return
        }

        guard let redirectTo = call.getString("redirectTo") else {
            call.reject("Missing redirectTo. Use an https URL on a trusted domain that opens your app.")
            return
        }
        let scopes = call.getString("scopes")

        Task {
            do {
                let url = try await client.socialSignInURL(provider: provider, callbackURL: redirectTo, scopes: scopes)
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
                call.resolve()
            } catch {
                call.reject("OAuth sign in failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func signInWithOtp(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let email = call.getString("email") else {
            call.reject("Missing email")
            return
        }

        Task {
            do {
                try await client.sendOtp(email: email)
                call.resolve()
            } catch {
                call.reject("OTP sign in failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func verifyOtp(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let email = call.getString("email"),
              let token = call.getString("token") else {
            call.reject("Missing email or token")
            return
        }
        let type = call.getString("type") ?? "email"

        Task {
            do {
                call.resolve(try await client.verifyOtp(email: email, token: token, type: type))
            } catch {
                call.reject("OTP verification failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func signOut(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        Task {
            do {
                try await client.signOut()
                call.resolve()
            } catch {
                call.reject("Sign out failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func getSession(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        Task {
            let session = try? await client.getSession()
            call.resolve(["session": session ?? NSNull()])
        }
    }

    @objc func refreshSession(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        Task {
            do {
                guard let session = try await client.getSession(forceRefresh: true) else {
                    call.reject("Session refresh failed: no active session")
                    return
                }
                call.resolve(["session": session])
            } catch {
                call.reject("Session refresh failed: \(error.localizedDescription)")
            }
        }
    }

    @objc func getUser(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        Task {
            let session = try? await client.getSession()
            call.resolve(["user": session?["user"] ?? NSNull()])
        }
    }

    @objc func setSession(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let refreshToken = call.getString("refreshToken") else {
            call.reject("Missing refreshToken")
            return
        }

        Task {
            do {
                let session = try await client.setSession(refreshToken: refreshToken)
                call.resolve(["session": session ?? NSNull()])
            } catch {
                call.reject("Set session failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Database Operations

    @objc func select(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let table = call.getString("table") else {
            call.reject("Missing table name")
            return
        }

        let columns = call.getString("columns") ?? "*"
        let filter = call.getObject("filter")
        let limit = call.getInt("limit")
        let offset = call.getInt("offset")
        let orderBy = call.getString("orderBy")
        let ascending = call.getBool("ascending") ?? true
        let single = call.getBool("single") ?? false

        Task {
            do {
                let data = try await client.select(table: table, columns: columns, filter: filter, limit: limit, offset: offset,
                                                   orderBy: orderBy, ascending: ascending, single: single)
                call.resolve(["data": data, "error": NSNull()])
            } catch {
                call.resolve(["data": NSNull(), "error": error.localizedDescription])
            }
        }
    }

    @objc func insert(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let table = call.getString("table") else {
            call.reject("Missing table name")
            return
        }

        guard let values: Any = call.getObject("values") ?? call.getArray("values") else {
            call.reject("Missing values to insert")
            return
        }

        Task {
            do {
                let data = try await client.insert(table: table, values: values)
                call.resolve(["data": data, "error": NSNull(), "count": (data as? [Any])?.count ?? 1])
            } catch {
                call.resolve(["data": NSNull(), "error": error.localizedDescription])
            }
        }
    }

    @objc func update(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let table = call.getString("table") else {
            call.reject("Missing table name")
            return
        }

        guard let values = call.getObject("values") else {
            call.reject("Missing values to update")
            return
        }

        guard let filter = call.getObject("filter"), !filter.isEmpty else {
            call.reject("Missing filter for update operation")
            return
        }

        Task {
            do {
                let data = try await client.update(table: table, values: values, filter: filter)
                call.resolve(["data": data, "error": NSNull(), "count": (data as? [Any])?.count ?? 0])
            } catch {
                call.resolve(["data": NSNull(), "error": error.localizedDescription])
            }
        }
    }

    @objc func delete(_ call: CAPPluginCall) {
        guard let client = neonClient else {
            call.reject("Neon client not initialized. Call initialize() first.")
            return
        }

        guard let table = call.getString("table") else {
            call.reject("Missing table name")
            return
        }

        guard let filter = call.getObject("filter"), !filter.isEmpty else {
            call.reject("Missing filter for delete operation")
            return
        }

        Task {
            do {
                let data = try await client.delete(table: table, filter: filter)
                call.resolve(["data": data, "error": NSNull(), "count": (data as? [Any])?.count ?? 0])
            } catch {
                call.resolve(["data": NSNull(), "error": error.localizedDescription])
            }
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.pluginVersion])
    }
}
