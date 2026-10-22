package com.capacitorneon.plugin

import android.net.Uri
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

/** Error surfaced to JavaScript as the rejection message. */
class NeonException(message: String) : Exception(message)

/** Persists the Neon Auth session cookie between app launches. */
interface NeonTokenStore {
    fun read(key: String): String?
    fun write(key: String, value: String?)
}

/**
 * Talks to Neon Auth (Managed Better Auth) and the Neon Data API over HTTP.
 *
 * Neon Auth keeps the session in a cookie. The client stores that cookie,
 * replays it on every auth request, and turns it into a short-lived JWT for
 * the Data API.
 */
class NeonClient(
    authUrl: String,
    dataApiUrl: String?,
    private val origin: String,
    private val store: NeonTokenStore,
    private val onAuthStateChange: (String, JSONObject?) -> Unit
) {
    companion object {
        const val SESSION_COOKIE_SUFFIX = ".session_token"
        val CHALLENGE_COOKIE_MARKERS = listOf(".session_challenge", ".session_challange")
        const val VERIFIER_PARAM = "neon_auth_session_verifier"
        const val DEFAULT_COOKIE_NAME = "__Secure-neon-auth.session_token"
        private val JSON = "application/json".toMediaType()
    }

    private val authUrl: HttpUrl = authUrl.trimEnd('/').toHttpUrl()
    private val dataApiUrl: HttpUrl? = dataApiUrl?.trimEnd('/')?.toHttpUrl()
    private val http = OkHttpClient.Builder().followRedirects(false).build()
    private val mutex = Mutex()

    private val sessionKey = "session:${this.authUrl}"
    private val challengeKey = "challenge:${this.authUrl}"

    private var cookieName: String? = null
    private var cookieValue: String? = null
    private var cachedSession: JSONObject? = null
    private var cachedJwtExp: Long = 0
    private var anonymousToken: Pair<String, Long>? = null

    init {
        store.read(sessionKey)?.let {
            runCatching { JSONObject(it) }.getOrNull()?.let { stored ->
                cookieName = stored.optString("name").ifEmpty { null }
                cookieValue = stored.optString("value").ifEmpty { null }
            }
        }
    }

    // region Auth

    /** Restores the stored session and emits INITIAL_SESSION. */
    suspend fun restore() = mutex.withLock {
        val session = if (cookieValue == null) null else runCatching { fetchSession(null) }.getOrNull()
        onAuthStateChange("INITIAL_SESSION", session)
    }

    suspend fun signInWithPassword(email: String, password: String): JSONObject = mutex.withLock {
        authRequest("POST", "/sign-in/email", body = JSONObject().put("email", email).put("password", password))
        completeSignIn()
    }

    suspend fun signUp(email: String, password: String, name: String?, image: String?): JSONObject = mutex.withLock {
        val body = JSONObject()
            .put("email", email)
            .put("password", password)
            .put("name", name ?: email.substringBefore("@"))
        image?.let { body.put("image", it) }
        val json = authRequest("POST", "/sign-up/email", body = body)
        if (cookieValue == null) {
            // Email verification is required, so there is no session yet.
            return@withLock JSONObject().put("session", JSONObject.NULL).put("user", userToJson(json?.optJSONObject("user")) ?: JSONObject.NULL)
        }
        completeSignIn()
    }

    suspend fun getAnonymousToken(): JSONObject = mutex.withLock {
        val (token, expiresAt) = currentAnonymousToken()
        JSONObject().put("token", token).put("expiresAt", expiresAt)
    }

    /** Starts social sign-in and returns the provider URL to open. */
    suspend fun socialSignInUrl(provider: String, callbackUrl: String, scopes: String?): String = mutex.withLock {
        val body = JSONObject()
            .put("provider", provider)
            .put("callbackURL", callbackUrl)
            .put("disableRedirect", true)
        scopes?.let { body.put("scopes", JSONArray(it.split(" ").filter { s -> s.isNotBlank() })) }
        val json = authRequest("POST", "/sign-in/social", body = body)
        json?.optString("url")?.ifEmpty { null } ?: throw NeonException("Neon Auth did not return an OAuth URL")
    }

    /**
     * Completes social sign-in when the app opens with a session verifier.
     * Returns false when the URL is not an OAuth callback.
     */
    suspend fun handleCallback(url: String): Boolean = mutex.withLock {
        // The callback can arrive on a custom scheme, which HttpUrl cannot parse.
        val verifier = runCatching { Uri.parse(url).getQueryParameter(VERIFIER_PARAM) }.getOrNull()
            ?: return@withLock false
        val challenge = store.read(challengeKey) ?: return@withLock false
        try {
            authRequest("GET", "/get-session", query = mapOf(VERIFIER_PARAM to verifier), cookieHeader = challenge)
            store.write(challengeKey, null)
            completeSignIn()
            true
        } catch (e: Exception) {
            Log.w("CapacitorNeon", "OAuth callback failed: ${e.message}")
            false
        }
    }

    suspend fun sendOtp(email: String) = mutex.withLock {
        authRequest("POST", "/email-otp/send-verification-otp", body = JSONObject().put("email", email).put("type", "sign-in"))
        Unit
    }

    suspend fun verifyOtp(email: String, token: String, type: String): JSONObject = mutex.withLock {
        val path = if (type == "signup") "/email-otp/verify-email" else "/sign-in/email-otp"
        val json = authRequest("POST", path, body = JSONObject().put("email", email).put("otp", token))
        if (cookieValue == null) {
            return@withLock JSONObject().put("session", JSONObject.NULL).put("user", userToJson(json?.optJSONObject("user")) ?: JSONObject.NULL)
        }
        completeSignIn()
    }

    suspend fun signOut() = mutex.withLock {
        if (cookieValue != null) {
            runCatching { authRequest("POST", "/sign-out", body = JSONObject()) }
        }
        clearSession()
        onAuthStateChange("SIGNED_OUT", null)
    }

    /**
     * Returns the current session, minting a new JWT when the cached one is
     * within a minute of expiry or [forceRefresh] is set.
     */
    suspend fun getSession(forceRefresh: Boolean = false): JSONObject? = mutex.withLock { currentSession(forceRefresh) }

    suspend fun setSession(refreshToken: String): JSONObject = mutex.withLock {
        setCookie(cookieName ?: DEFAULT_COOKIE_NAME, refreshToken)
        cachedSession = null
        val session = fetchSession(null) ?: throw NeonException("Invalid or expired refresh token")
        onAuthStateChange("SIGNED_IN", session)
        session
    }

    // endregion

    // region Data API

    suspend fun select(
        table: String,
        columns: String,
        filter: JSONObject?,
        limit: Int?,
        offset: Int?,
        orderBy: String?,
        ascending: Boolean,
        single: Boolean
    ): Any = mutex.withLock {
        val query = linkedMapOf("select" to columns.filterNot { it.isWhitespace() })
        query.putAll(filterParams(filter))
        orderBy?.let { query["order"] = "$it.${if (ascending) "asc" else "desc"}" }
        limit?.let { query["limit"] = it.toString() }
        offset?.let { query["offset"] = it.toString() }
        val headers = if (single) mapOf("Accept" to "application/vnd.pgrst.object+json") else emptyMap()
        dataRequest("GET", table, query, headers = headers)
    }

    suspend fun insert(table: String, values: Any): Any = mutex.withLock {
        val query = linkedMapOf("select" to "*")
        var prefer = "return=representation"
        if (values is JSONArray) {
            // Rows with different keys need an explicit column list.
            val columns = (0 until values.length()).mapNotNull { values.optJSONObject(it) }
                .flatMap { it.keys().asSequence().toList() }.toSortedSet()
            query["columns"] = columns.joinToString(",")
            prefer += ",missing=default"
        }
        val rows = dataRequest("POST", table, query, values, mapOf("Prefer" to prefer))
        if (values is JSONObject && rows is JSONArray) {
            if (rows.length() > 0) rows.get(0) else JSONObject.NULL
        } else {
            rows
        }
    }

    suspend fun update(table: String, values: JSONObject, filter: JSONObject): Any = mutex.withLock {
        dataRequest("PATCH", table, filterParams(filter) + ("select" to "*"), values, mapOf("Prefer" to "return=representation"))
    }

    suspend fun delete(table: String, filter: JSONObject): Any = mutex.withLock {
        dataRequest("DELETE", table, filterParams(filter) + ("select" to "*"), headers = mapOf("Prefer" to "return=representation"))
    }

    // endregion

    // region Internals

    private suspend fun completeSignIn(): JSONObject {
        val session = fetchSession(null) ?: throw NeonException("Neon Auth did not return a session")
        onAuthStateChange("SIGNED_IN", session)
        return JSONObject().put("session", session).put("user", session.opt("user") ?: JSONObject.NULL)
    }

    private suspend fun currentSession(forceRefresh: Boolean): JSONObject? {
        if (cookieValue == null) return null
        val now = System.currentTimeMillis() / 1000
        val cached = cachedSession
        if (!forceRefresh && cached != null && cachedJwtExp - now > 60) {
            return withExpiresIn(cached)
        }
        return fetchSession(if (cached != null) "TOKEN_REFRESHED" else null)
    }

    /** Calls /get-session, which also returns a fresh JWT in `set-auth-jwt`. */
    private suspend fun fetchSession(event: String?): JSONObject? {
        val (json, headers) = authRequestWithHeaders("GET", "/get-session", query = mapOf("disableCookieCache" to "true"))
        val sessionJson = json?.optJSONObject("session")
        val user = userToJson(json?.optJSONObject("user"))
        val token = cookieValue
        if (sessionJson == null || user == null || token == null) {
            clearSession()
            if (event != null) onAuthStateChange("SIGNED_OUT", null)
            return null
        }
        val accessToken = headers["set-auth-jwt"]
            ?: authRequest("GET", "/token")?.optString("token")?.ifEmpty { null }
            ?: throw NeonException("Neon Auth did not return a JWT")
        val exp = jwtExpiry(accessToken) ?: (System.currentTimeMillis() / 1000 + 900)
        val session = JSONObject()
            .put("accessToken", accessToken)
            .put("refreshToken", token)
            .put("tokenType", "bearer")
            .put("expiresAt", exp)
            .put("user", user)
        sessionJson.optString("expiresAt").ifEmpty { null }?.let { session.put("sessionExpiresAt", it) }
        cachedSession = session
        cachedJwtExp = exp
        val result = withExpiresIn(session)
        event?.let { onAuthStateChange(it, result) }
        return result
    }

    private fun withExpiresIn(session: JSONObject): JSONObject {
        val copy = JSONObject(session.toString())
        val exp = session.optLong("expiresAt")
        copy.put("expiresIn", maxOf(0, exp - System.currentTimeMillis() / 1000))
        return copy
    }

    private suspend fun currentAnonymousToken(): Pair<String, Long> {
        val now = System.currentTimeMillis() / 1000
        anonymousToken?.let { if (it.second - now > 60) return it }
        val json = authRequest("GET", "/token/anonymous")
        val token = json?.optString("token")?.ifEmpty { null } ?: throw NeonException("Neon Auth did not return an anonymous token")
        val expiresAt = json.optLong("expires_at").takeIf { it > 0 } ?: jwtExpiry(token) ?: (now + 900)
        return (token to expiresAt).also { anonymousToken = it }
    }

    private suspend fun authRequest(
        method: String,
        path: String,
        query: Map<String, String> = emptyMap(),
        body: JSONObject? = null,
        cookieHeader: String? = null
    ): JSONObject? = authRequestWithHeaders(method, path, query, body, cookieHeader).first

    private suspend fun authRequestWithHeaders(
        method: String,
        path: String,
        query: Map<String, String> = emptyMap(),
        body: JSONObject? = null,
        cookieHeader: String? = null
    ): Pair<JSONObject?, Map<String, String>> {
        val url = authUrl.newBuilder().addPathSegments(path.trimStart('/')).apply {
            query.forEach { (k, v) -> addQueryParameter(k, v) }
        }.build()
        val request = Request.Builder()
            .url(url)
            .header("Origin", origin)
            .header("Accept", "application/json")
            .apply {
                (cookieHeader ?: sessionCookieHeader())?.let { header("Cookie", it) }
                method(method, body?.toString()?.toRequestBody(JSON))
            }
            .build()

        return execute(request) { response, text ->
            captureCookies(response)
            val json = text.takeIf { it.isNotBlank() }?.let { runCatching { JSONTokener(it).nextValue() }.getOrNull() }
            if (!response.isSuccessful) {
                val obj = json as? JSONObject
                val message = obj?.optString("message")?.ifEmpty { null }
                    ?: obj?.optString("error")?.ifEmpty { null }
                    ?: "HTTP ${response.code}"
                throw NeonException(message)
            }
            val headers = response.headers.names().associate { it.lowercase() to (response.header(it) ?: "") }
            (json as? JSONObject) to headers
        }
    }

    private suspend fun dataRequest(
        method: String,
        table: String,
        query: Map<String, String>,
        body: Any? = null,
        headers: Map<String, String> = emptyMap()
    ): Any {
        val base = dataApiUrl ?: throw NeonException("Data API URL not configured. Pass dataApiUrl to initialize().")
        val token = currentSession(false)?.optString("accessToken")?.ifEmpty { null } ?: currentAnonymousToken().first

        val url = base.newBuilder().addPathSegment(table).apply {
            query.forEach { (k, v) -> addQueryParameter(k, v) }
        }.build()
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/json")
            .apply {
                headers.forEach { (k, v) -> header(k, v) }
                method(method, body?.toString()?.toRequestBody(JSON))
            }
            .build()

        return execute(request) { response, text ->
            val json = text.takeIf { it.isNotBlank() }?.let { runCatching { JSONTokener(it).nextValue() }.getOrNull() }
            if (!response.isSuccessful) {
                val message = (json as? JSONObject)?.optString("message")?.ifEmpty { null } ?: "HTTP ${response.code}"
                throw NeonException(message)
            }
            json ?: JSONObject.NULL
        }
    }

    private suspend fun <T> execute(request: Request, handle: (Response, String) -> T): T = withContext(Dispatchers.IO) {
        http.newCall(request).execute().use { response -> handle(response, response.body.string()) }
    }

    private fun filterParams(filter: JSONObject?): Map<String, String> {
        if (filter == null) return emptyMap()
        return filter.keys().asSequence().sorted().associateWith { key ->
            when (val value = filter.opt(key)) {
                null, JSONObject.NULL -> "is.null"
                is Boolean -> "eq.$value"
                else -> "eq.$value"
            }
        }
    }

    // endregion

    // region Cookies

    private fun sessionCookieHeader(): String? {
        val name = cookieName ?: return null
        val value = cookieValue ?: return null
        return "$name=$value"
    }

    private fun captureCookies(response: Response) {
        val challenges = mutableListOf<String>()
        for (header in response.headers("Set-Cookie")) {
            val pair = header.substringBefore(";")
            val name = pair.substringBefore("=").trim()
            val value = pair.substringAfter("=", "").trim()
            val attributes = header.substringAfter(";", "").lowercase()
            val expired = value.isEmpty() || Regex("max-age=(-?\\d+)").find(attributes)?.groupValues?.get(1)?.toLong()?.let { it <= 0 } == true
            when {
                name.endsWith(SESSION_COOKIE_SUFFIX) -> if (expired) clearSession() else setCookie(name, value)
                CHALLENGE_COOKIE_MARKERS.any { name.endsWith(it) } -> challenges.add("$name=$value")
            }
        }
        if (challenges.isNotEmpty()) store.write(challengeKey, challenges.joinToString("; "))
    }

    private fun setCookie(name: String, value: String) {
        cookieName = name
        cookieValue = value
        store.write(sessionKey, JSONObject().put("name", name).put("value", value).toString())
    }

    private fun clearSession() {
        cookieValue = null
        cachedSession = null
        cachedJwtExp = 0
        store.write(sessionKey, null)
    }

    // endregion

    // region Mapping

    private fun userToJson(user: JSONObject?): JSONObject? {
        val id = user?.optString("id")?.ifEmpty { null } ?: return null
        val result = JSONObject().put("id", id)
        for (key in listOf("email", "name", "image", "role", "createdAt", "updatedAt")) {
            user.optString(key).takeIf { user.has(key) && !user.isNull(key) }?.let { result.put(key, it) }
        }
        if (user.has("emailVerified")) result.put("emailVerified", user.optBoolean("emailVerified"))
        user.optString("phoneNumber").takeIf { user.has("phoneNumber") && !user.isNull("phoneNumber") }?.let { result.put("phone", it) }
        return result
    }

    private fun jwtExpiry(jwt: String): Long? {
        val parts = jwt.split(".")
        if (parts.size != 3) return null
        return runCatching {
            val payload = String(Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP))
            JSONObject(payload).optLong("exp").takeIf { it > 0 }
        }.getOrNull()
    }

    // endregion
}
