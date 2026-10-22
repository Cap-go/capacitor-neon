import Foundation

/// Error surfaced to JavaScript as the rejection message.
struct NeonError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Persists the Neon Auth session cookie between app launches.
protocol NeonTokenStore {
    func read(_ key: String) -> String?
    func write(_ key: String, _ value: String?)
}

/// Talks to Neon Auth (Managed Better Auth) and the Neon Data API over HTTP.
///
/// Neon Auth keeps the session in a cookie. The client stores that cookie,
/// replays it on every auth request, and turns it into a short-lived JWT for
/// the Data API.
actor NeonClient {
    static let sessionCookieSuffix = ".session_token"
    static let challengeCookieMarkers = [".session_challenge", ".session_challange"]
    static let verifierParam = "neon_auth_session_verifier"
    static let defaultCookieName = "__Secure-neon-auth.session_token"

    typealias AuthStateHandler = @Sendable (String, [String: Any]?) -> Void

    private let authURL: URL
    private let dataApiURL: URL?
    private let origin: String
    private let store: NeonTokenStore
    private let onAuthStateChange: AuthStateHandler
    private let http: URLSession

    private var cookieName: String?
    private var cookieValue: String?
    private var cachedSession: [String: Any]?
    private var cachedJwtExp: Int = 0
    private var anonymousToken: (token: String, expiresAt: Int)?

    init(authURL: URL, dataApiURL: URL?, origin: String, store: NeonTokenStore, onAuthStateChange: @escaping AuthStateHandler) {
        self.authURL = authURL
        self.dataApiURL = dataApiURL
        self.origin = origin
        self.store = store
        self.onAuthStateChange = onAuthStateChange

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        self.http = URLSession(configuration: config)

        let stored = store.read("session:\(authURL.absoluteString)")
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        self.cookieName = stored?["name"]
        self.cookieValue = stored?["value"]
    }

    private var sessionKey: String { "session:\(authURL.absoluteString)" }
    private var challengeKey: String { "challenge:\(authURL.absoluteString)" }

    // MARK: - Auth

    /// Restores the stored session and emits INITIAL_SESSION.
    func restore() async {
        let session = cookieValue == nil ? nil : try? await fetchSession(event: nil)
        onAuthStateChange("INITIAL_SESSION", session)
    }

    func signInWithPassword(email: String, password: String) async throws -> [String: Any] {
        _ = try await authRequest("POST", "/sign-in/email", body: ["email": email, "password": password])
        return try await completeSignIn()
    }

    func signUp(email: String, password: String, name: String?, image: String?) async throws -> [String: Any] {
        var body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name ?? String(email.split(separator: "@").first ?? Substring(email))
        ]
        if let image = image {
            body["image"] = image
        }
        let json = try await authRequest("POST", "/sign-up/email", body: body)
        if cookieValue == nil {
            // Email verification is required, so there is no session yet.
            return ["session": NSNull(), "user": userToDict(json?["user"] as? [String: Any]) ?? NSNull()]
        }
        return try await completeSignIn()
    }

    func getAnonymousToken() async throws -> [String: Any] {
        let token = try await currentAnonymousToken()
        return ["token": token.token, "expiresAt": token.expiresAt]
    }

    /// Starts social sign-in and returns the provider URL to open.
    func socialSignInURL(provider: String, callbackURL: String, scopes: String?) async throws -> URL {
        var body: [String: Any] = ["provider": provider, "callbackURL": callbackURL, "disableRedirect": true]
        if let scopes = scopes {
            body["scopes"] = scopes.split(separator: " ").map(String.init)
        }
        let json = try await authRequest("POST", "/sign-in/social", body: body)
        guard let urlString = json?["url"] as? String, let url = URL(string: urlString) else {
            throw NeonError(message: "Neon Auth did not return an OAuth URL")
        }
        return url
    }

    /// Completes social sign-in when the app opens with a session verifier.
    /// Returns false when the URL is not an OAuth callback.
    func handleCallback(url: URL) async -> Bool {
        guard let verifier = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == Self.verifierParam })?.value,
              let challenge = store.read(challengeKey) else {
            return false
        }
        do {
            _ = try await authRequest(
                "GET",
                "/get-session",
                query: [URLQueryItem(name: Self.verifierParam, value: verifier)],
                cookieHeader: challenge
            )
            store.write(challengeKey, nil)
            _ = try await completeSignIn()
            return true
        } catch {
            return false
        }
    }

    func sendOtp(email: String) async throws {
        _ = try await authRequest("POST", "/email-otp/send-verification-otp", body: ["email": email, "type": "sign-in"])
    }

    func verifyOtp(email: String, token: String, type: String) async throws -> [String: Any] {
        let path = type == "signup" ? "/email-otp/verify-email" : "/sign-in/email-otp"
        let json = try await authRequest("POST", path, body: ["email": email, "otp": token])
        if cookieValue == nil {
            return ["session": NSNull(), "user": userToDict(json?["user"] as? [String: Any]) ?? NSNull()]
        }
        return try await completeSignIn()
    }

    func signOut() async throws {
        if cookieValue != nil {
            _ = try? await authRequest("POST", "/sign-out", body: [:])
        }
        clearSession()
        onAuthStateChange("SIGNED_OUT", nil)
    }

    /// Returns the current session, minting a new JWT when the cached one is
    /// within a minute of expiry or `forceRefresh` is set.
    func getSession(forceRefresh: Bool = false) async throws -> [String: Any]? {
        guard cookieValue != nil else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        if !forceRefresh, let cached = cachedSession, cachedJwtExp - now > 60 {
            return withExpiresIn(cached)
        }
        let hadSession = cachedSession != nil
        return try await fetchSession(event: hadSession ? "TOKEN_REFRESHED" : nil)
    }

    func setSession(refreshToken: String) async throws -> [String: Any]? {
        setCookie(name: cookieName ?? Self.defaultCookieName, value: refreshToken)
        cachedSession = nil
        guard let session = try await fetchSession(event: nil) else {
            throw NeonError(message: "Invalid or expired refresh token")
        }
        onAuthStateChange("SIGNED_IN", session)
        return session
    }

    // MARK: - Data API

    func select(table: String, columns: String, filter: [String: Any]?, limit: Int?, offset: Int?,
                orderBy: String?, ascending: Bool, single: Bool) async throws -> Any {
        var query = [URLQueryItem(name: "select", value: columns.filter { !$0.isWhitespace })]
        query += filterItems(filter)
        if let orderBy = orderBy {
            query.append(URLQueryItem(name: "order", value: "\(orderBy).\(ascending ? "asc" : "desc")"))
        }
        if let limit = limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            query.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        var headers: [String: String] = [:]
        if single {
            headers["Accept"] = "application/vnd.pgrst.object+json"
        }
        return try await dataRequest("GET", table: table, query: query, headers: headers)
    }

    func insert(table: String, values: Any) async throws -> Any {
        var query = [URLQueryItem(name: "select", value: "*")]
        var prefer = "return=representation"
        if let array = values as? [[String: Any]] {
            // Rows with different keys need an explicit column list.
            let columns = Set(array.flatMap { $0.keys }).sorted()
            query.append(URLQueryItem(name: "columns", value: columns.joined(separator: ",")))
            prefer += ",missing=default"
        }
        let rows = try await dataRequest("POST", table: table, query: query, body: values, headers: ["Prefer": prefer])
        if values is [String: Any], let array = rows as? [Any] {
            return array.first ?? NSNull()
        }
        return rows
    }

    func update(table: String, values: [String: Any], filter: [String: Any]) async throws -> Any {
        try await dataRequest("PATCH", table: table, query: filterItems(filter) + [URLQueryItem(name: "select", value: "*")],
                              body: values, headers: ["Prefer": "return=representation"])
    }

    func delete(table: String, filter: [String: Any]) async throws -> Any {
        try await dataRequest("DELETE", table: table, query: filterItems(filter) + [URLQueryItem(name: "select", value: "*")],
                              headers: ["Prefer": "return=representation"])
    }

    // MARK: - Internals

    private func completeSignIn() async throws -> [String: Any] {
        guard let session = try await fetchSession(event: nil) else {
            throw NeonError(message: "Neon Auth did not return a session")
        }
        onAuthStateChange("SIGNED_IN", session)
        return ["session": session, "user": session["user"] ?? NSNull()]
    }

    /// Calls /get-session, which also returns a fresh JWT in `set-auth-jwt`.
    private func fetchSession(event: String?) async throws -> [String: Any]? {
        let (json, headers) = try await authRequestWithHeaders("GET", "/get-session", query: [URLQueryItem(name: "disableCookieCache", value: "true")])
        guard let json = json,
              let sessionJson = json["session"] as? [String: Any],
              let user = userToDict(json["user"] as? [String: Any]),
              let cookieValue = cookieValue else {
            clearSession()
            if event != nil {
                onAuthStateChange("SIGNED_OUT", nil)
            }
            return nil
        }
        var jwt = headers["set-auth-jwt"]
        if jwt == nil {
            let tokenJson = try await authRequest("GET", "/token")
            jwt = tokenJson?["token"] as? String
        }
        guard let accessToken = jwt else {
            throw NeonError(message: "Neon Auth did not return a JWT")
        }
        let exp = jwtExpiry(accessToken) ?? Int(Date().timeIntervalSince1970) + 900
        var session: [String: Any] = [
            "accessToken": accessToken,
            "refreshToken": cookieValue,
            "tokenType": "bearer",
            "expiresAt": exp,
            "user": user
        ]
        if let sessionExpiresAt = sessionJson["expiresAt"] as? String {
            session["sessionExpiresAt"] = sessionExpiresAt
        }
        cachedSession = session
        cachedJwtExp = exp
        let result = withExpiresIn(session)
        if let event = event {
            onAuthStateChange(event, result)
        }
        return result
    }

    private func withExpiresIn(_ session: [String: Any]) -> [String: Any] {
        var copy = session
        let exp = session["expiresAt"] as? Int ?? 0
        copy["expiresIn"] = max(0, exp - Int(Date().timeIntervalSince1970))
        return copy
    }

    private func currentAnonymousToken() async throws -> (token: String, expiresAt: Int) {
        let now = Int(Date().timeIntervalSince1970)
        if let cached = anonymousToken, cached.expiresAt - now > 60 {
            return cached
        }
        let json = try await authRequest("GET", "/token/anonymous")
        guard let token = json?["token"] as? String else {
            throw NeonError(message: "Neon Auth did not return an anonymous token")
        }
        let expiresAt = (json?["expires_at"] as? NSNumber)?.intValue ?? jwtExpiry(token) ?? now + 900
        anonymousToken = (token, expiresAt)
        return (token, expiresAt)
    }

    private func authRequest(_ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil,
                             cookieHeader: String? = nil) async throws -> [String: Any]? {
        try await authRequestWithHeaders(method, path, query: query, body: body, cookieHeader: cookieHeader).0
    }

    private func authRequestWithHeaders(_ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil,
                                        cookieHeader: String? = nil) async throws -> ([String: Any]?, [String: String]) {
        var components = URLComponents(url: authURL.appendingPathComponent(String(path.dropFirst())), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw NeonError(message: "Invalid auth URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(origin, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cookie = cookieHeader ?? sessionCookieHeader() {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NeonError(message: "Invalid response")
        }
        captureCookies(httpResponse, url: url)

        let json = data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data)
        guard (200..<300).contains(httpResponse.statusCode) else {
            let dict = json as? [String: Any]
            let message = dict?["message"] as? String ?? dict?["error"] as? String ?? "HTTP \(httpResponse.statusCode)"
            throw NeonError(message: message)
        }
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key.lowercased()] = value
            }
        }
        return (json as? [String: Any], headers)
    }

    private func dataRequest(_ method: String, table: String, query: [URLQueryItem], body: Any? = nil,
                             headers: [String: String] = [:]) async throws -> Any {
        guard let dataApiURL = dataApiURL else {
            throw NeonError(message: "Data API URL not configured. Pass dataApiUrl to initialize().")
        }
        let token: String
        if let session = try await getSession(), let accessToken = session["accessToken"] as? String {
            token = accessToken
        } else {
            token = try await currentAnonymousToken().token
        }

        var components = URLComponents(url: dataApiURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = query.map { "\(encode($0.name))=\(encode($0.value ?? ""))" }.joined(separator: "&")
        guard let url = components?.url else {
            throw NeonError(message: "Invalid table name")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NeonError(message: "Invalid response")
        }
        let json = data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard (200..<300).contains(httpResponse.statusCode) else {
            let dict = json as? [String: Any]
            throw NeonError(message: dict?["message"] as? String ?? "HTTP \(httpResponse.statusCode)")
        }
        return json ?? NSNull()
    }

    private func filterItems(_ filter: [String: Any]?) -> [URLQueryItem] {
        guard let filter = filter else { return [] }
        return filter.keys.sorted().map { key in
            let value = filter[key]
            let text: String
            if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
                text = number.boolValue ? "true" : "false"
            } else if value is NSNull {
                return URLQueryItem(name: key, value: "is.null")
            } else {
                text = "\(value ?? "")"
            }
            return URLQueryItem(name: key, value: "eq.\(text)")
        }
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~*,()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: - Cookies

    private func sessionCookieHeader() -> String? {
        guard let name = cookieName, let value = cookieValue else { return nil }
        return "\(name)=\(value)"
    }

    private func captureCookies(_ response: HTTPURLResponse, url: URL) {
        var fields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                fields[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        var challenges: [String] = []
        for cookie in cookies {
            if cookie.name.hasSuffix(Self.sessionCookieSuffix) {
                let expired = cookie.value.isEmpty || (cookie.expiresDate.map { $0 <= Date() } ?? false)
                if expired {
                    clearSession()
                } else {
                    setCookie(name: cookie.name, value: cookie.value)
                }
            } else if Self.challengeCookieMarkers.contains(where: { cookie.name.hasSuffix($0) }) {
                challenges.append("\(cookie.name)=\(cookie.value)")
            }
        }
        if !challenges.isEmpty {
            store.write(challengeKey, challenges.joined(separator: "; "))
        }
    }

    private func setCookie(name: String, value: String) {
        cookieName = name
        cookieValue = value
        if let data = try? JSONSerialization.data(withJSONObject: ["name": name, "value": value]) {
            store.write(sessionKey, String(data: data, encoding: .utf8))
        }
    }

    private func clearSession() {
        cookieValue = nil
        cachedSession = nil
        cachedJwtExp = 0
        store.write(sessionKey, nil)
    }

    // MARK: - Mapping

    private func userToDict(_ user: [String: Any]?) -> [String: Any]? {
        guard let user = user, let id = user["id"] as? String else { return nil }
        var dict: [String: Any] = ["id": id]
        for key in ["email", "name", "image", "role", "createdAt", "updatedAt"] {
            if let value = user[key] as? String {
                dict[key] = value
            }
        }
        if let emailVerified = user["emailVerified"] as? Bool {
            dict["emailVerified"] = emailVerified
        }
        if let phone = user["phoneNumber"] as? String {
            dict["phone"] = phone
        }
        return dict
    }

    private func jwtExpiry(_ jwt: String) -> Int? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (payload["exp"] as? NSNumber)?.intValue
    }
}
