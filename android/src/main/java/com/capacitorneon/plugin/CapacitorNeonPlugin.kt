package com.capacitorneon.plugin

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

/** Stores the Neon Auth session cookie in app-private SharedPreferences. */
private class PreferencesTokenStore(context: Context) : NeonTokenStore {
    private val prefs = context.getSharedPreferences("CapacitorNeon", Context.MODE_PRIVATE)

    override fun read(key: String): String? = prefs.getString(key, null)

    override fun write(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }
}

@CapacitorPlugin(name = "CapacitorNeon")
class CapacitorNeonPlugin : Plugin() {
    private val pluginVersion = "8.0.0"
    private var neonClient: NeonClient? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var pendingCallbackUrl: String? = null

    override fun load() {
        // The app may have been cold-started by the OAuth redirect.
        activity?.intent?.data?.toString()?.let { onCallbackUrl(it) }
    }

    override fun handleOnNewIntent(intent: Intent) {
        super.handleOnNewIntent(intent)
        intent.data?.toString()?.let { onCallbackUrl(it) }
    }

    override fun handleOnDestroy() {
        scope.cancel()
        super.handleOnDestroy()
    }

    private fun onCallbackUrl(url: String) {
        if (!url.contains(NeonClient.VERIFIER_PARAM)) return
        val client = neonClient
        if (client == null) {
            // The app opened from the OAuth redirect before initialize() ran.
            pendingCallbackUrl = url
            return
        }
        scope.launch { client.handleCallback(url) }
    }

    @PluginMethod
    fun initialize(call: PluginCall) {
        val authUrl = call.getString("authUrl")
        if (authUrl.isNullOrEmpty()) {
            call.reject("Missing authUrl")
            return
        }

        val client = try {
            NeonClient(
                authUrl = authUrl,
                dataApiUrl = call.getString("dataApiUrl")?.ifEmpty { null },
                origin = call.getString("origin") ?: "https://localhost",
                store = PreferencesTokenStore(context)
            ) { event, session ->
                val data = JSObject()
                data.put("event", event)
                data.put("session", session ?: JSONObject.NULL)
                notifyListeners("authStateChange", data, event == "INITIAL_SESSION")
            }
        } catch (e: Exception) {
            call.reject("Failed to initialize Neon client: ${e.message}")
            return
        }
        neonClient = client

        val pendingUrl = pendingCallbackUrl
        pendingCallbackUrl = null
        scope.launch {
            client.restore()
            pendingUrl?.let { client.handleCallback(it) }
            call.resolve()
        }
    }

    @PluginMethod
    fun signInWithPassword(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val email = call.getString("email")
        val password = call.getString("password")
        if (email.isNullOrEmpty() || password.isNullOrEmpty()) {
            call.reject("Missing email or password")
            return
        }

        scope.launch {
            try {
                call.resolve(JSObject.fromJSONObject(client.signInWithPassword(email, password)))
            } catch (e: Exception) {
                call.reject("Sign in failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun signUp(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val email = call.getString("email")
        val password = call.getString("password")
        if (email.isNullOrEmpty() || password.isNullOrEmpty()) {
            call.reject("Missing email or password")
            return
        }

        scope.launch {
            try {
                call.resolve(JSObject.fromJSONObject(client.signUp(email, password, call.getString("name"), call.getString("image"))))
            } catch (e: Exception) {
                call.reject("Sign up failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun getAnonymousToken(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        scope.launch {
            try {
                call.resolve(JSObject.fromJSONObject(client.getAnonymousToken()))
            } catch (e: Exception) {
                call.reject("Anonymous token failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun signInWithOAuth(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val provider = call.getString("provider")?.lowercase()
        if (provider == null || provider !in listOf("google", "github", "vercel")) {
            call.reject("Missing or invalid provider")
            return
        }

        val redirectTo = call.getString("redirectTo")
        if (redirectTo.isNullOrEmpty()) {
            call.reject("Missing redirectTo. Use an https URL on a trusted domain that opens your app.")
            return
        }

        scope.launch {
            try {
                val url = client.socialSignInUrl(provider, redirectTo, call.getString("scopes"))
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                call.resolve()
            } catch (e: Exception) {
                call.reject("OAuth sign in failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun signInWithOtp(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val email = call.getString("email")
        if (email.isNullOrEmpty()) {
            call.reject("Missing email")
            return
        }

        scope.launch {
            try {
                client.sendOtp(email)
                call.resolve()
            } catch (e: Exception) {
                call.reject("OTP sign in failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun verifyOtp(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val email = call.getString("email")
        val token = call.getString("token")
        if (email.isNullOrEmpty() || token.isNullOrEmpty()) {
            call.reject("Missing email or token")
            return
        }

        scope.launch {
            try {
                call.resolve(JSObject.fromJSONObject(client.verifyOtp(email, token, call.getString("type") ?: "email")))
            } catch (e: Exception) {
                call.reject("OTP verification failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun signOut(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        scope.launch {
            try {
                client.signOut()
                call.resolve()
            } catch (e: Exception) {
                call.reject("Sign out failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun getSession(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        scope.launch {
            val session = runCatching { client.getSession() }.getOrNull()
            call.resolve(JSObject().put("session", session ?: JSONObject.NULL))
        }
    }

    @PluginMethod
    fun refreshSession(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        scope.launch {
            try {
                val session = client.getSession(forceRefresh = true)
                if (session == null) {
                    call.reject("Session refresh failed: no active session")
                } else {
                    call.resolve(JSObject().put("session", session))
                }
            } catch (e: Exception) {
                call.reject("Session refresh failed: ${e.message}")
            }
        }
    }

    @PluginMethod
    fun getUser(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        scope.launch {
            val session = runCatching { client.getSession() }.getOrNull()
            call.resolve(JSObject().put("user", session?.opt("user") ?: JSONObject.NULL))
        }
    }

    @PluginMethod
    fun setSession(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val refreshToken = call.getString("refreshToken")
        if (refreshToken.isNullOrEmpty()) {
            call.reject("Missing refreshToken")
            return
        }

        scope.launch {
            try {
                call.resolve(JSObject().put("session", client.setSession(refreshToken)))
            } catch (e: Exception) {
                call.reject("Set session failed: ${e.message}")
            }
        }
    }

    // Database Operations

    @PluginMethod
    fun select(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val table = call.getString("table")
        if (table.isNullOrEmpty()) {
            call.reject("Missing table name")
            return
        }

        scope.launch {
            try {
                val data = client.select(
                    table = table,
                    columns = call.getString("columns") ?: "*",
                    filter = call.getObject("filter"),
                    limit = call.getInt("limit"),
                    offset = call.getInt("offset"),
                    orderBy = call.getString("orderBy"),
                    ascending = call.getBoolean("ascending") ?: true,
                    single = call.getBoolean("single") ?: false
                )
                call.resolve(JSObject().put("data", data).put("error", JSONObject.NULL))
            } catch (e: Exception) {
                call.resolve(JSObject().put("data", JSONObject.NULL).put("error", e.message))
            }
        }
    }

    @PluginMethod
    fun insert(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val table = call.getString("table")
        if (table.isNullOrEmpty()) {
            call.reject("Missing table name")
            return
        }

        val values: Any = call.data.opt("values")?.takeIf { it is JSONObject || it is JSONArray }
            ?: return call.reject("Missing values to insert")

        scope.launch {
            try {
                val data = client.insert(table, values)
                val count = if (data is JSONArray) data.length() else 1
                call.resolve(JSObject().put("data", data).put("error", JSONObject.NULL).put("count", count))
            } catch (e: Exception) {
                call.resolve(JSObject().put("data", JSONObject.NULL).put("error", e.message))
            }
        }
    }

    @PluginMethod
    fun update(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val table = call.getString("table")
        if (table.isNullOrEmpty()) {
            call.reject("Missing table name")
            return
        }

        val values = call.getObject("values") ?: return call.reject("Missing values to update")

        val filter = call.getObject("filter")
        if (filter == null || filter.length() == 0) {
            call.reject("Missing filter for update operation")
            return
        }

        scope.launch {
            try {
                val data = client.update(table, values, filter)
                val count = (data as? JSONArray)?.length() ?: 0
                call.resolve(JSObject().put("data", data).put("error", JSONObject.NULL).put("count", count))
            } catch (e: Exception) {
                call.resolve(JSObject().put("data", JSONObject.NULL).put("error", e.message))
            }
        }
    }

    @PluginMethod
    fun delete(call: PluginCall) {
        val client = neonClient ?: return call.reject("Neon client not initialized. Call initialize() first.")

        val table = call.getString("table")
        if (table.isNullOrEmpty()) {
            call.reject("Missing table name")
            return
        }

        val filter = call.getObject("filter")
        if (filter == null || filter.length() == 0) {
            call.reject("Missing filter for delete operation")
            return
        }

        scope.launch {
            try {
                val data = client.delete(table, filter)
                val count = (data as? JSONArray)?.length() ?: 0
                call.resolve(JSObject().put("data", data).put("error", JSONObject.NULL).put("count", count))
            } catch (e: Exception) {
                call.resolve(JSObject().put("data", JSONObject.NULL).put("error", e.message))
            }
        }
    }

    @PluginMethod
    fun getPluginVersion(call: PluginCall) {
        try {
            val ret = JSObject()
            ret.put("version", pluginVersion)
            call.resolve(ret)
        } catch (e: Exception) {
            call.reject("Could not get plugin version", e)
        }
    }
}
