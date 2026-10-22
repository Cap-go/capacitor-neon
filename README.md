# capacitor-neon

Use Neon Auth and the Neon Data API natively from your Capacitor app for auth and database calls, and get JWTs for your web layer.

<a href="https://capgo.app/?ref=plugin_neon"><img src="https://raw.githubusercontent.com/rishi-raj-jain/capacitor-neon/main/assets/readme-banner.svg" alt="Capgo - Build Capacitor apps with AI, ship updates instantly" /></a>

<div align="center">
  <p><b>Capgo</b>: push fixes to your Capacitor users in minutes, build signed iOS and Android apps without a Mac, and roll back in one click.</p>
  <h2><a href="https://capgo.app/register/?ref=plugin_neon">➡️ Get started for free</a></h2>
  <p>14-day unlimited free trial. No credit card required</p>
</div>

> 🤖 **Building with an AI coding agent?** Install [Capgo skills](https://capgo.app/skills/?ref=plugin_neon) so Claude Code, Codex, Cursor, Copilot, or Gemini CLI know how to install and use `capacitor-neon` in your Capacitor app: `npx skills add Cap-go/capgo-skills`. Then ask your agent: *"Add capacitor-neon to my Capacitor app and wire it up."* [Agent setup guides](https://capgo.app/agents/?ref=plugin_neon) · [Hosted MCP](https://capgo.app/docs/ai/mcp/?ref=plugin_neon)

<p align="center">
  <img src="https://raw.githubusercontent.com/rishi-raj-jain/capacitor-neon/main/assets/github-social-preview.png" alt="capacitor-neon for Capacitor apps" width="300" />
</p>

## Key features

- **Auth methods**: email and password, sign up, OAuth providers (Google, GitHub, Vercel) and email OTP with `verifyOtp()`.
- **Sessions**: `getSession()`, `refreshSession()`, `setSession()`, `getUser()` and `signOut()`, with the `authStateChange` event.
- **JWT access**: sessions include the Neon Auth JWT for the Data API, Neon Functions, or your own API.
- **Database**: `select()`, `insert()`, `update()` and `delete()` on your tables through the Neon Data API, with RLS.
- **Native HTTP**: URLSession on iOS and OkHttp on Android. The session is stored in the iOS Keychain and in app-private storage on Android.
- **Platforms**: iOS and Android. On web, use `@neondatabase/neon-js` directly.

## Why Capacitor Neon?

A native Neon Auth integration that provides **real native authentication** with JWT token access for your Capacitor apps:

- **Native session handling** - The Neon Auth session cookie is captured and stored natively, never exposed to WebView cookie storage
- **JWT token access** - Get JWT tokens from native auth for use in JavaScript/web layers
- **Complete auth methods** - Email/password, OAuth, and email OTP
- **Session management** - Sessions persist across app restarts, and a new JWT is minted when the cached one is about to expire
- **Database operations** - Native CRUD operations for Neon Data API tables
- **Auth state listeners** - Real-time auth state change events
- **Hybrid approach** - Use native auth with `@neondatabase/neon-js` for database queries
- **Free and open source** - No paid services required

Perfect for apps that need secure native authentication while using Neon's Postgres, Auth, and Data API.

**Why only Auth and basic DB operations?** The Neon JS SDK already works in Capacitor for database queries through the Data API. Neon Auth keeps the session in an HTTP-only cookie, and the browser SDK depends on cookies and redirects that do not behave well inside a Capacitor WebView. This plugin focuses on **authentication**, where native code provides real value (cookie handling, secure token storage, OAuth redirects back into the app). For everything else, use `@neondatabase/neon-js` with the JWT from native auth.

**Why not bridge everything natively?**
- **No performance gain** - The bridge overhead (JSON serialization/deserialization between JS and native) negates any benefit from skipping HTTP preflight requests. You're just moving the transformation cost from network to CPU.
- **Type safety issue** - Native code would need typed models for every table/query. You'd need to define Swift/Kotlin types for your entire database schema and keep them in sync. With JS, you get dynamic typing that just works.
- **Maintenance burden** - Every Neon SDK update would require updating 3 codebases (JS, iOS, Android) instead of just one.

## Documentation

- Neon Auth: https://neon.com/docs/auth/overview
- Neon Data API: https://neon.com/docs/data-api/get-started

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |

> **Note:** The major version of this plugin follows the major version of Capacitor. Use the version that matches your Capacitor installation (e.g., plugin v8 for Capacitor 8). Only the latest major version is actively maintained.

## Install

You can use our AI-Assisted Setup to install the plugin. Add the Capgo skills to your AI tool using the following command:

```bash
npx skills add https://github.com/cap-go/capacitor-skills --skill capacitor-plugins
```

Then use the following prompt:

```text
Use the `capacitor-plugins` skill from `cap-go/capacitor-skills` to install the `capacitor-neon` plugin in my project.
```

If you prefer Manual Setup, install the plugin by running the following commands and follow the platform-specific instructions below:

```bash
npm install capacitor-neon
npx cap sync
```

## Neon Setup

1. Enable **Neon Auth** on your branch (Console > Auth, or `neon neon-auth enable`).
2. Enable the **Data API** on the same branch if you want the database methods (Console > Data API, with Neon Auth as the provider).
3. Copy the **Auth URL** and **Data API URL** from the Console.

Neon Auth only accepts requests from trusted origins. Localhost is trusted by default, and the plugin sends `Origin: https://localhost`, so a new branch works without changes. If you turn off localhost, add one of your domains as a trusted domain and pass it as `origin` to `initialize()`.

## iOS Setup

No additional setup required for email and OTP sign-in. The plugin uses URLSession and the Keychain, with no third-party dependencies.

For OAuth, set up a Universal Link or a custom URL scheme for the `redirectTo` URL you pass to `signInWithOAuth()` (see [OAuth Sign In](#oauth-sign-in)).

## Android Setup

No additional setup required for email and OTP sign-in. The plugin works with the Capacitor 8 default minimum SDK of 24 (Android 7.0). Make sure your `android/variables.gradle` has at least:

```gradle
minSdkVersion = 24
```

For OAuth, set up an App Link or a custom URL scheme for the `redirectTo` URL you pass to `signInWithOAuth()` (see [OAuth Sign In](#oauth-sign-in)).

## Usage

### Initialize the Client

```typescript
import { CapacitorNeon } from 'capacitor-neon';

await CapacitorNeon.initialize({
  authUrl: 'https://ep-xxx.neonauth.us-east-2.aws.neon.tech/neondb/auth',
  dataApiUrl: 'https://ep-xxx.apirest.us-east-2.aws.neon.tech/neondb/rest/v1'
});
```

### Authentication

#### Sign In with Email/Password

```typescript
const { session, user } = await CapacitorNeon.signInWithPassword({
  email: 'user@example.com',
  password: 'password123'
});

// Access the JWT token
console.log('JWT:', session?.accessToken);
```

#### Sign Up

```typescript
const { session, user } = await CapacitorNeon.signUp({
  email: 'newuser@example.com',
  password: 'password123',
  name: 'John Doe'
});
```

If **Verify email at sign-up** is on for your branch, `session` is `null` until the user confirms the code with `verifyOtp({ type: 'signup' })`.

#### Anonymous Access

Neon Auth has no anonymous user accounts. Instead, it issues anonymous JWTs for the `anonymous` Postgres role, so RLS policies for that role apply. The database methods use one automatically when no one is signed in. You can also fetch it yourself:

```typescript
const { token, expiresAt } = await CapacitorNeon.getAnonymousToken();
```

#### OAuth Sign In

```typescript
await CapacitorNeon.signInWithOAuth({
  provider: 'google',
  redirectTo: 'https://app.example.com/auth/callback'
});
```

The plugin opens the provider in the system browser. After the user signs in, Neon Auth redirects to `redirectTo` with a `neon_auth_session_verifier` query parameter. When that URL opens your app, the plugin exchanges the verifier for a session and emits `SIGNED_IN`.

Neon Auth only redirects to `http` or `https` URLs on a trusted domain, so custom schemes like `myapp://` are rejected. There are two ways to get back into your app.

**Universal Links / App Links.** Use an https URL that opens your app directly:

1. Add the domain as a trusted domain: `neon neon-auth domain add https://app.example.com`
2. iOS: add `applinks:app.example.com` to Associated Domains and host an `apple-app-site-association` file.
3. Android: add an `autoVerify` intent filter for the domain and host an `assetlinks.json` file.

**Bounce page.** Host a small page on a trusted domain that forwards the query string to your app's custom URL scheme, for example `https://app.example.com/auth/callback?neon_auth_session_verifier=...` to `myapp://auth/callback?neon_auth_session_verifier=...`. The plugin accepts the callback on either URL, as long as it carries `neon_auth_session_verifier`. Register the scheme in `CFBundleURLTypes` on iOS and in an intent filter on Android. The example app ships [`oauth-bounce.mjs`](example-app/oauth-bounce.mjs), which runs this page on `http://localhost:8787` for local testing, since localhost is trusted by default.

Google works out of the box with Neon's shared development credentials. GitHub and Vercel, and Google in production, need your own OAuth apps: https://neon.com/docs/auth/guides/setup-oauth

#### OTP Sign In

```typescript
// Send OTP
await CapacitorNeon.signInWithOtp({
  email: 'user@example.com'
});

// Verify OTP
const { session, user } = await CapacitorNeon.verifyOtp({
  email: 'user@example.com',
  token: '123456',
  type: 'email'
});
```

Signing in with a code creates the account if the email is new.

#### Sign Out

```typescript
await CapacitorNeon.signOut();
```

### Session Management

#### Get Current Session

```typescript
const { session } = await CapacitorNeon.getSession();
if (session) {
  console.log('JWT:', session.accessToken);
  console.log('Refresh Token:', session.refreshToken);
  console.log('Expires At:', session.expiresAt);
}
```

Neon Auth JWTs expire after 15 minutes. `getSession()` returns the cached JWT and mints a new one when it is within a minute of expiry.

#### Refresh Session

```typescript
const { session } = await CapacitorNeon.refreshSession();
```

#### Get Current User

```typescript
const { user } = await CapacitorNeon.getUser();
if (user) {
  console.log('User ID:', user.id);
  console.log('Email:', user.email);
}
```

#### Set Session Manually

```typescript
const { session } = await CapacitorNeon.setSession({
  refreshToken: 'abc123.signature'
});
```

`refreshToken` is the Neon Auth session token from `Session.refreshToken`.

### Listen to Auth State Changes

```typescript
const listener = await CapacitorNeon.addListener(
  'authStateChange',
  ({ event, session }) => {
    console.log('Auth event:', event);
    // Events: INITIAL_SESSION, SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED
    if (session) {
      console.log('JWT:', session.accessToken);
    }
  }
);

// Later, remove the listener
listener.remove();
```

### Using JWT with @neondatabase/neon-js

The main use case is to get the JWT from native auth and use it with the JavaScript Data API client:

```typescript
import { createClient } from '@neondatabase/neon-js';
import { CapacitorNeon } from 'capacitor-neon';

// Initialize native client
await CapacitorNeon.initialize({
  authUrl: 'https://ep-xxx.neonauth.us-east-2.aws.neon.tech/neondb/auth'
});

// Sign in natively
await CapacitorNeon.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
});

// Create a JS Data API client that reads the JWT from native auth
const neon = createClient({
  dataApi: {
    url: 'https://ep-xxx.apirest.us-east-2.aws.neon.tech/neondb/rest/v1',
    getToken: async () => (await CapacitorNeon.getSession()).session?.accessToken ?? null
  }
});

// Now use neon-js as normal
const { data } = await neon.from('table').select('*');
```

### Database Operations (Native)

The plugin also supports native database operations through the Neon Data API:

#### Select

```typescript
const { data, error } = await CapacitorNeon.select({
  table: 'users',
  columns: 'id, name, email',
  filter: { active: true },
  limit: 10,
  orderBy: 'created_at',
  ascending: false
});
```

#### Insert

```typescript
const { data, error } = await CapacitorNeon.insert({
  table: 'posts',
  values: { title: 'Hello', content: 'World' }
});
```

Pass an array to insert several rows at once. Rows can have different columns, and missing columns get their default values:

```typescript
const { data, count } = await CapacitorNeon.insert({
  table: 'posts',
  values: [{ title: 'First', published: true }, { title: 'Second' }]
});
```

#### Update

```typescript
const { data, error } = await CapacitorNeon.update({
  table: 'posts',
  values: { title: 'Updated Title' },
  filter: { id: 1 }
});
```

#### Delete

```typescript
const { data, error } = await CapacitorNeon.delete({
  table: 'posts',
  filter: { id: 1 }
});
```

## API

<docgen-index>

* [`initialize(...)`](#initialize)
* [`signInWithPassword(...)`](#signinwithpassword)
* [`signUp(...)`](#signup)
* [`getAnonymousToken()`](#getanonymoustoken)
* [`signInWithOAuth(...)`](#signinwithoauth)
* [`signInWithOtp(...)`](#signinwithotp)
* [`verifyOtp(...)`](#verifyotp)
* [`signOut()`](#signout)
* [`getSession()`](#getsession)
* [`refreshSession()`](#refreshsession)
* [`getUser()`](#getuser)
* [`setSession(...)`](#setsession)
* [`addListener('authStateChange', ...)`](#addlistenerauthstatechange-)
* [`removeAllListeners()`](#removealllisteners)
* [`select(...)`](#select)
* [`insert(...)`](#insert)
* [`update(...)`](#update)
* [`delete(...)`](#delete)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capacitor Neon Plugin for native Neon Auth and Data API integration.

This plugin runs Neon Auth sign-in natively on iOS and Android, keeps the
session in secure native storage, and gives you JWT tokens for use in
JavaScript/web layers.

### initialize(...)

```typescript
initialize(options: NeonConfig) => Promise<void>
```

Initialize the Neon client with your branch URLs.
Must be called before any other methods. Restores a stored session and
emits `INITIAL_SESSION`.

| Param         | Type                                              | Description                               |
| ------------- | ------------------------------------------------- | ----------------------------------------- |
| **`options`** | <code><a href="#neonconfig">NeonConfig</a></code> | - Neon Auth URL and optional Data API URL |

**Since:** 0.0.1

--------------------


### signInWithPassword(...)

```typescript
signInWithPassword(options: SignInWithPasswordOptions) => Promise<AuthResult>
```

Sign in with email and password.

| Param         | Type                                                                            | Description                      |
| ------------- | ------------------------------------------------------------------------------- | -------------------------------- |
| **`options`** | <code><a href="#signinwithpasswordoptions">SignInWithPasswordOptions</a></code> | - Email and password credentials |

**Returns:** <code>Promise&lt;<a href="#authresult">AuthResult</a>&gt;</code>

**Since:** 0.0.1

--------------------


### signUp(...)

```typescript
signUp(options: SignUpOptions) => Promise<AuthResult>
```

Sign up a new user with email and password.

| Param         | Type                                                    | Description                                    |
| ------------- | ------------------------------------------------------- | ---------------------------------------------- |
| **`options`** | <code><a href="#signupoptions">SignUpOptions</a></code> | - Email, password, and optional name and image |

**Returns:** <code>Promise&lt;<a href="#authresult">AuthResult</a>&gt;</code>

**Since:** 0.0.1

--------------------


### getAnonymousToken()

```typescript
getAnonymousToken() => Promise<AnonymousToken>
```

Get an anonymous Data API token.
Neon Auth has no anonymous user accounts. This token lets signed-out users
query the Data API as the `anonymous` Postgres role, so RLS policies for
that role apply. Database methods use it automatically when no one is
signed in.

**Returns:** <code>Promise&lt;<a href="#anonymoustoken">AnonymousToken</a>&gt;</code>

**Since:** 0.0.1

--------------------


### signInWithOAuth(...)

```typescript
signInWithOAuth(options: SignInWithOAuthOptions) => Promise<void>
```

Sign in with an OAuth provider.
Opens the provider's authentication page in the system browser. When your
app reopens at `redirectTo`, the plugin completes sign-in and emits
`SIGNED_IN`.

| Param         | Type                                                                      | Description                       |
| ------------- | ------------------------------------------------------------------------- | --------------------------------- |
| **`options`** | <code><a href="#signinwithoauthoptions">SignInWithOAuthOptions</a></code> | - OAuth provider and redirect URL |

**Since:** 0.0.1

--------------------


### signInWithOtp(...)

```typescript
signInWithOtp(options: SignInWithOtpOptions) => Promise<void>
```

Sign in with OTP (One-Time Password) sent via email.

| Param         | Type                                                                  | Description                    |
| ------------- | --------------------------------------------------------------------- | ------------------------------ |
| **`options`** | <code><a href="#signinwithotpoptions">SignInWithOtpOptions</a></code> | - Email address to send OTP to |

**Since:** 0.0.1

--------------------


### verifyOtp(...)

```typescript
verifyOtp(options: VerifyOtpOptions) => Promise<AuthResult>
```

Verify an OTP token.

| Param         | Type                                                          | Description                           |
| ------------- | ------------------------------------------------------------- | ------------------------------------- |
| **`options`** | <code><a href="#verifyotpoptions">VerifyOtpOptions</a></code> | - Email, token, and verification type |

**Returns:** <code>Promise&lt;<a href="#authresult">AuthResult</a>&gt;</code>

**Since:** 0.0.1

--------------------


### signOut()

```typescript
signOut() => Promise<void>
```

Sign out the current user.

**Since:** 0.0.1

--------------------


### getSession()

```typescript
getSession() => Promise<{ session: Session | null; }>
```

Get the current session if one exists.
Returns the session with JWT access token, minting a new one when the
cached token is close to expiry.

**Returns:** <code>Promise&lt;{ session: <a href="#session">Session</a> | null; }&gt;</code>

**Since:** 0.0.1

--------------------


### refreshSession()

```typescript
refreshSession() => Promise<{ session: Session | null; }>
```

Refresh the current session and get a new access token.

**Returns:** <code>Promise&lt;{ session: <a href="#session">Session</a> | null; }&gt;</code>

**Since:** 0.0.1

--------------------


### getUser()

```typescript
getUser() => Promise<{ user: User | null; }>
```

Get the currently authenticated user.

**Returns:** <code>Promise&lt;{ user: <a href="#user">User</a> | null; }&gt;</code>

**Since:** 0.0.1

--------------------


### setSession(...)

```typescript
setSession(options: SetSessionOptions) => Promise<{ session: Session | null; }>
```

Set the session manually from a refresh token.
Useful for restoring a session or integrating with external auth.

| Param         | Type                                                            | Description                               |
| ------------- | --------------------------------------------------------------- | ----------------------------------------- |
| **`options`** | <code><a href="#setsessionoptions">SetSessionOptions</a></code> | - Refresh token and optional access token |

**Returns:** <code>Promise&lt;{ session: <a href="#session">Session</a> | null; }&gt;</code>

**Since:** 0.0.1

--------------------


### addListener('authStateChange', ...)

```typescript
addListener(eventName: 'authStateChange', listenerFunc: (data: AuthStateChange) => void) => Promise<PluginListenerHandle>
```

Listen to authentication state changes.

| Param              | Type                                                                           | Description                                |
| ------------------ | ------------------------------------------------------------------------------ | ------------------------------------------ |
| **`eventName`**    | <code>'authStateChange'</code>                                                 | - Must be 'authStateChange'                |
| **`listenerFunc`** | <code>(data: <a href="#authstatechange">AuthStateChange</a>) =&gt; void</code> | - Callback function for auth state changes |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 0.0.1

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

Remove all listeners for auth state changes.

**Since:** 0.0.1

--------------------


### select(...)

```typescript
select<T = unknown>(options: SelectOptions) => Promise<QueryResult<T[]>>
```

Execute a SELECT query on a table through the Neon Data API.

| Param         | Type                                                    | Description                                       |
| ------------- | ------------------------------------------------------- | ------------------------------------------------- |
| **`options`** | <code><a href="#selectoptions">SelectOptions</a></code> | - Query options including table, columns, filters |

**Returns:** <code>Promise&lt;<a href="#queryresult">QueryResult</a>&lt;T[]&gt;&gt;</code>

**Since:** 0.0.1

--------------------


### insert(...)

```typescript
insert<T = unknown>(options: InsertOptions) => Promise<QueryResult<T>>
```

Insert data into a table through the Neon Data API.

| Param         | Type                                                    | Description                       |
| ------------- | ------------------------------------------------------- | --------------------------------- |
| **`options`** | <code><a href="#insertoptions">InsertOptions</a></code> | - Table name and values to insert |

**Returns:** <code>Promise&lt;<a href="#queryresult">QueryResult</a>&lt;T&gt;&gt;</code>

**Since:** 0.0.1

--------------------


### update(...)

```typescript
update<T = unknown>(options: UpdateOptions) => Promise<QueryResult<T>>
```

Update data in a table through the Neon Data API.

| Param         | Type                                                    | Description                                           |
| ------------- | ------------------------------------------------------- | ----------------------------------------------------- |
| **`options`** | <code><a href="#updateoptions">UpdateOptions</a></code> | - Table name, values to update, and filter conditions |

**Returns:** <code>Promise&lt;<a href="#queryresult">QueryResult</a>&lt;T&gt;&gt;</code>

**Since:** 0.0.1

--------------------


### delete(...)

```typescript
delete<T = unknown>(options: DeleteOptions) => Promise<QueryResult<T>>
```

Delete data from a table through the Neon Data API.

| Param         | Type                                                    | Description                        |
| ------------- | ------------------------------------------------------- | ---------------------------------- |
| **`options`** | <code><a href="#deleteoptions">DeleteOptions</a></code> | - Table name and filter conditions |

**Returns:** <code>Promise&lt;<a href="#queryresult">QueryResult</a>&lt;T&gt;&gt;</code>

**Since:** 0.0.1

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor plugin version.

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

**Since:** 0.0.1

--------------------


### Interfaces


#### NeonConfig

Configuration options for initializing the Neon client.

| Prop             | Type                | Description                                                                                                                                                                                                                            | Default                          | Since |
| ---------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | ----- |
| **`authUrl`**    | <code>string</code> | The Neon Auth URL of your branch (includes the `/neondb/auth` path). Find it in the Neon Console under Auth, or with `neon neon-auth status`.                                                                                          |                                  | 0.0.1 |
| **`dataApiUrl`** | <code>string</code> | The Neon Data API URL of your branch. Required for `select()`, `insert()`, `update()` and `delete()`.                                                                                                                                  |                                  | 0.0.1 |
| **`origin`**     | <code>string</code> | The `Origin` header sent to Neon Auth. Neon Auth only accepts requests from trusted origins. Localhost is trusted by default, so the default works on a new branch. Set this to one of your trusted domains if you disabled localhost. | <code>"https://localhost"</code> | 0.0.1 |


#### AuthResult

Result of authentication operations that return a session.

| Prop          | Type                                                | Description                                   | Since |
| ------------- | --------------------------------------------------- | --------------------------------------------- | ----- |
| **`session`** | <code><a href="#session">Session</a> \| null</code> | The session if authentication was successful. | 0.0.1 |
| **`user`**    | <code><a href="#user">User</a> \| null</code>       | The authenticated user if successful.         | 0.0.1 |


#### Session

<a href="#session">Session</a> object containing authentication tokens.

| Prop                   | Type                                  | Description                                                                                                                             | Since |
| ---------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`accessToken`**      | <code>string</code>                   | The JWT access token (EdDSA, 15-minute expiry). Use this for the Neon Data API, Neon Functions, or your own API.                        | 0.0.1 |
| **`refreshToken`**     | <code>string</code>                   | The Neon Auth session token. The plugin uses it to mint new access tokens. Pass it to `setSession()` to restore this session elsewhere. | 0.0.1 |
| **`tokenType`**        | <code>string</code>                   | Token type (always "bearer").                                                                                                           | 0.0.1 |
| **`expiresIn`**        | <code>number</code>                   | Number of seconds until the access token expires.                                                                                       | 0.0.1 |
| **`expiresAt`**        | <code>number</code>                   | Unix timestamp when the access token expires.                                                                                           | 0.0.1 |
| **`sessionExpiresAt`** | <code>string</code>                   | Timestamp when the Neon Auth session itself expires.                                                                                    | 0.0.1 |
| **`user`**             | <code><a href="#user">User</a></code> | The authenticated user.                                                                                                                 | 0.0.1 |


#### User

<a href="#user">User</a> object returned from authentication operations.

| Prop                | Type                 | Description                                                         | Since |
| ------------------- | -------------------- | ------------------------------------------------------------------- | ----- |
| **`id`**            | <code>string</code>  | Unique identifier for the user.                                     | 0.0.1 |
| **`email`**         | <code>string</code>  | <a href="#user">User</a>'s email address.                           | 0.0.1 |
| **`name`**          | <code>string</code>  | <a href="#user">User</a>'s display name.                            | 0.0.1 |
| **`image`**         | <code>string</code>  | URL of the user's avatar image.                                     | 0.0.1 |
| **`emailVerified`** | <code>boolean</code> | Whether the user's email address is verified.                       | 0.0.1 |
| **`phone`**         | <code>string</code>  | <a href="#user">User</a>'s phone number (Phone Number plugin only). | 0.0.1 |
| **`role`**          | <code>string</code>  | The user's role, such as "user" or "admin".                         | 0.0.1 |
| **`createdAt`**     | <code>string</code>  | Timestamp when the user was created.                                | 0.0.1 |
| **`updatedAt`**     | <code>string</code>  | Timestamp when the user was last updated.                           | 0.0.1 |


#### SignInWithPasswordOptions

Options for email/password sign-in.

| Prop           | Type                | Description                               | Since |
| -------------- | ------------------- | ----------------------------------------- | ----- |
| **`email`**    | <code>string</code> | <a href="#user">User</a>'s email address. | 0.0.1 |
| **`password`** | <code>string</code> | <a href="#user">User</a>'s password.      | 0.0.1 |


#### SignUpOptions

Options for email/password sign-up.

| Prop           | Type                | Description                                                                                                                                    | Since |
| -------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`email`**    | <code>string</code> | <a href="#user">User</a>'s email address.                                                                                                      | 0.0.1 |
| **`password`** | <code>string</code> | <a href="#user">User</a>'s password.                                                                                                           | 0.0.1 |
| **`name`**     | <code>string</code> | <a href="#user">User</a>'s display name. Neon Auth requires a name, so the plugin uses the part of the email before "@" when you leave it out. | 0.0.1 |
| **`image`**    | <code>string</code> | URL of the user's avatar image.                                                                                                                | 0.0.1 |


#### AnonymousToken

Anonymous Data API token.

| Prop            | Type                | Description                                            | Since |
| --------------- | ------------------- | ------------------------------------------------------ | ----- |
| **`token`**     | <code>string</code> | JWT for the `anonymous` Postgres role on the Data API. | 0.0.1 |
| **`expiresAt`** | <code>number</code> | Unix timestamp when the token expires.                 | 0.0.1 |


#### SignInWithOAuthOptions

Options for OAuth sign-in.

| Prop             | Type                                                    | Description                                                                                                                                                                                                       | Since |
| ---------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`provider`**   | <code><a href="#oauthprovider">OAuthProvider</a></code> | The OAuth provider to use.                                                                                                                                                                                        | 0.0.1 |
| **`redirectTo`** | <code>string</code>                                     | HTTPS URL that opens your app after authentication, such as an iOS Universal Link or an Android App Link. Its origin must be a trusted domain in Neon Auth. Neon Auth rejects custom URL schemes like `myapp://`. | 0.0.1 |
| **`scopes`**     | <code>string</code>                                     | OAuth scopes to request, separated by spaces.                                                                                                                                                                     | 0.0.1 |


#### SignInWithOtpOptions

Options for OTP sign-in.

| Prop        | Type                | Description                               | Since |
| ----------- | ------------------- | ----------------------------------------- | ----- |
| **`email`** | <code>string</code> | <a href="#user">User</a>'s email address. | 0.0.1 |


#### VerifyOtpOptions

Options for verifying OTP.

| Prop        | Type                             | Description                                                                                                                                       | Default              | Since |
| ----------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | ----- |
| **`email`** | <code>string</code>              | <a href="#user">User</a>'s email address.                                                                                                         |                      | 0.0.1 |
| **`token`** | <code>string</code>              | The OTP token received via email.                                                                                                                 |                      | 0.0.1 |
| **`type`**  | <code>'email' \| 'signup'</code> | The type of OTP verification. `email` signs the user in with a code from `signInWithOtp()`. `signup` verifies the email address of a new account. | <code>"email"</code> | 0.0.1 |


#### SetSessionOptions

Options for setting a session manually.

| Prop               | Type                | Description                                                                                     | Since |
| ------------------ | ------------------- | ----------------------------------------------------------------------------------------------- | ----- |
| **`accessToken`**  | <code>string</code> | The access token. Optional, since the plugin mints a fresh one from the refresh token.          | 0.0.1 |
| **`refreshToken`** | <code>string</code> | The refresh token (Neon Auth session token) from <a href="#session">`Session.refreshToken`</a>. | 0.0.1 |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### AuthStateChange

Auth state change callback data.

| Prop          | Type                                                        | Description                               | Since |
| ------------- | ----------------------------------------------------------- | ----------------------------------------- | ----- |
| **`event`**   | <code><a href="#authchangeevent">AuthChangeEvent</a></code> | The type of auth event.                   | 0.0.1 |
| **`session`** | <code><a href="#session">Session</a> \| null</code>         | The current session (null if signed out). | 0.0.1 |


#### QueryResult

Result of database queries.

| Prop        | Type                        | Description                                         | Since |
| ----------- | --------------------------- | --------------------------------------------------- | ----- |
| **`data`**  | <code>T \| null</code>      | The query result data.                              | 0.0.1 |
| **`error`** | <code>string \| null</code> | Error message if the query failed.                  | 0.0.1 |
| **`count`** | <code>number</code>         | Number of affected rows (for insert/update/delete). | 0.0.1 |


#### SelectOptions

Options for database select queries.

| Prop            | Type                                                             | Description                                                                                     | Since |
| --------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ----- |
| **`table`**     | <code>string</code>                                              | The table name to query.                                                                        | 0.0.1 |
| **`columns`**   | <code>string</code>                                              | Columns to select (default: "*").                                                               | 0.0.1 |
| **`filter`**    | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Filter conditions as key-value pairs. Each pair matches rows where the column equals the value. | 0.0.1 |
| **`limit`**     | <code>number</code>                                              | Maximum number of rows to return.                                                               | 0.0.1 |
| **`offset`**    | <code>number</code>                                              | Number of rows to skip.                                                                         | 0.0.1 |
| **`orderBy`**   | <code>string</code>                                              | Column to order by.                                                                             | 0.0.1 |
| **`ascending`** | <code>boolean</code>                                             | Order direction.                                                                                | 0.0.1 |
| **`single`**    | <code>boolean</code>                                             | Return a single row instead of an array.                                                        | 0.0.1 |


#### InsertOptions

Options for database insert queries.

| Prop         | Type                                                                                                                      | Description                                             | Since |
| ------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ----- |
| **`table`**  | <code>string</code>                                                                                                       | The table name to insert into.                          | 0.0.1 |
| **`values`** | <code><a href="#record">Record</a>&lt;string, unknown&gt; \| <a href="#record">Record</a>&lt;string, unknown&gt;[]</code> | The data to insert (single object or array of objects). | 0.0.1 |


#### UpdateOptions

Options for database update queries.

| Prop         | Type                                                             | Description                                | Since |
| ------------ | ---------------------------------------------------------------- | ------------------------------------------ | ----- |
| **`table`**  | <code>string</code>                                              | The table name to update.                  | 0.0.1 |
| **`values`** | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | The data to update.                        | 0.0.1 |
| **`filter`** | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Filter conditions to match rows to update. | 0.0.1 |


#### DeleteOptions

Options for database delete queries.

| Prop         | Type                                                             | Description                                | Since |
| ------------ | ---------------------------------------------------------------- | ------------------------------------------ | ----- |
| **`table`**  | <code>string</code>                                              | The table name to delete from.             | 0.0.1 |
| **`filter`** | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Filter conditions to match rows to delete. | 0.0.1 |


### Type Aliases


#### OAuthProvider

OAuth providers supported by Neon Auth.

<code>'google' | 'github' | 'vercel'</code>


#### AuthChangeEvent

Auth state change event types.

<code>'INITIAL_SESSION' | 'SIGNED_IN' | 'SIGNED_OUT' | 'TOKEN_REFRESHED'</code>


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>

</docgen-api>
