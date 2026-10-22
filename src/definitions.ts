import type { PluginListenerHandle } from '@capacitor/core';

/**
 * Configuration options for initializing the Neon client.
 *
 * @since 0.0.1
 */
export interface NeonConfig {
  /**
   * The Neon Auth URL of your branch (includes the `/neondb/auth` path).
   * Find it in the Neon Console under Auth, or with `neon neon-auth status`.
   *
   * @since 0.0.1
   * @example "https://ep-xxx.neonauth.us-east-2.aws.neon.tech/neondb/auth"
   */
  authUrl: string;

  /**
   * The Neon Data API URL of your branch. Required for `select()`, `insert()`,
   * `update()` and `delete()`.
   *
   * @since 0.0.1
   * @example "https://ep-xxx.apirest.us-east-2.aws.neon.tech/neondb/rest/v1"
   */
  dataApiUrl?: string;

  /**
   * The `Origin` header sent to Neon Auth. Neon Auth only accepts requests from
   * trusted origins. Localhost is trusted by default, so the default works on a
   * new branch. Set this to one of your trusted domains if you disabled
   * localhost.
   *
   * @since 0.0.1
   * @default "https://localhost"
   */
  origin?: string;
}

/**
 * User object returned from authentication operations.
 *
 * @since 0.0.1
 */
export interface User {
  /**
   * Unique identifier for the user.
   *
   * @since 0.0.1
   */
  id: string;

  /**
   * User's email address.
   *
   * @since 0.0.1
   */
  email?: string;

  /**
   * User's display name.
   *
   * @since 0.0.1
   */
  name?: string;

  /**
   * URL of the user's avatar image.
   *
   * @since 0.0.1
   */
  image?: string;

  /**
   * Whether the user's email address is verified.
   *
   * @since 0.0.1
   */
  emailVerified?: boolean;

  /**
   * User's phone number (Phone Number plugin only).
   *
   * @since 0.0.1
   */
  phone?: string;

  /**
   * The user's role, such as "user" or "admin".
   *
   * @since 0.0.1
   */
  role?: string;

  /**
   * Timestamp when the user was created.
   *
   * @since 0.0.1
   */
  createdAt?: string;

  /**
   * Timestamp when the user was last updated.
   *
   * @since 0.0.1
   */
  updatedAt?: string;
}

/**
 * Session object containing authentication tokens.
 *
 * @since 0.0.1
 */
export interface Session {
  /**
   * The JWT access token (EdDSA, 15-minute expiry). Use this for the Neon Data
   * API, Neon Functions, or your own API.
   *
   * @since 0.0.1
   */
  accessToken: string;

  /**
   * The Neon Auth session token. The plugin uses it to mint new access tokens.
   * Pass it to `setSession()` to restore this session elsewhere.
   *
   * @since 0.0.1
   */
  refreshToken: string;

  /**
   * Token type (always "bearer").
   *
   * @since 0.0.1
   */
  tokenType: string;

  /**
   * Number of seconds until the access token expires.
   *
   * @since 0.0.1
   */
  expiresIn: number;

  /**
   * Unix timestamp when the access token expires.
   *
   * @since 0.0.1
   */
  expiresAt?: number;

  /**
   * Timestamp when the Neon Auth session itself expires.
   *
   * @since 0.0.1
   */
  sessionExpiresAt?: string;

  /**
   * The authenticated user.
   *
   * @since 0.0.1
   */
  user: User;
}

/**
 * Result of authentication operations that return a session.
 *
 * @since 0.0.1
 */
export interface AuthResult {
  /**
   * The session if authentication was successful.
   *
   * @since 0.0.1
   */
  session: Session | null;

  /**
   * The authenticated user if successful.
   *
   * @since 0.0.1
   */
  user: User | null;
}

/**
 * Options for email/password sign-in.
 *
 * @since 0.0.1
 */
export interface SignInWithPasswordOptions {
  /**
   * User's email address.
   *
   * @since 0.0.1
   */
  email: string;

  /**
   * User's password.
   *
   * @since 0.0.1
   */
  password: string;
}

/**
 * Options for email/password sign-up.
 *
 * @since 0.0.1
 */
export interface SignUpOptions {
  /**
   * User's email address.
   *
   * @since 0.0.1
   */
  email: string;

  /**
   * User's password.
   *
   * @since 0.0.1
   */
  password: string;

  /**
   * User's display name. Neon Auth requires a name, so the plugin uses the
   * part of the email before "@" when you leave it out.
   *
   * @since 0.0.1
   */
  name?: string;

  /**
   * URL of the user's avatar image.
   *
   * @since 0.0.1
   */
  image?: string;
}

/**
 * Options for OAuth sign-in.
 *
 * @since 0.0.1
 */
export interface SignInWithOAuthOptions {
  /**
   * The OAuth provider to use.
   *
   * @since 0.0.1
   */
  provider: OAuthProvider;

  /**
   * HTTPS URL that opens your app after authentication, such as an iOS
   * Universal Link or an Android App Link. Its origin must be a trusted domain
   * in Neon Auth. Neon Auth rejects custom URL schemes like `myapp://`.
   *
   * @since 0.0.1
   * @example "https://app.example.com/auth/callback"
   */
  redirectTo: string;

  /**
   * OAuth scopes to request, separated by spaces.
   *
   * @since 0.0.1
   */
  scopes?: string;
}

/**
 * OAuth providers supported by Neon Auth.
 *
 * @since 0.0.1
 */
export type OAuthProvider = 'google' | 'github' | 'vercel';

/**
 * Options for OTP sign-in.
 *
 * @since 0.0.1
 */
export interface SignInWithOtpOptions {
  /**
   * User's email address.
   *
   * @since 0.0.1
   */
  email: string;
}

/**
 * Options for verifying OTP.
 *
 * @since 0.0.1
 */
export interface VerifyOtpOptions {
  /**
   * User's email address.
   *
   * @since 0.0.1
   */
  email: string;

  /**
   * The OTP token received via email.
   *
   * @since 0.0.1
   */
  token: string;

  /**
   * The type of OTP verification. `email` signs the user in with a code from
   * `signInWithOtp()`. `signup` verifies the email address of a new account.
   *
   * @since 0.0.1
   * @default "email"
   */
  type?: 'email' | 'signup';
}

/**
 * Options for setting a session manually.
 *
 * @since 0.0.1
 */
export interface SetSessionOptions {
  /**
   * The access token. Optional, since the plugin mints a fresh one from the
   * refresh token.
   *
   * @since 0.0.1
   */
  accessToken?: string;

  /**
   * The refresh token (Neon Auth session token) from `Session.refreshToken`.
   *
   * @since 0.0.1
   */
  refreshToken: string;
}

/**
 * Anonymous Data API token.
 *
 * @since 0.0.1
 */
export interface AnonymousToken {
  /**
   * JWT for the `anonymous` Postgres role on the Data API.
   *
   * @since 0.0.1
   */
  token: string;

  /**
   * Unix timestamp when the token expires.
   *
   * @since 0.0.1
   */
  expiresAt: number;
}

/**
 * Auth state change event types.
 *
 * @since 0.0.1
 */
export type AuthChangeEvent = 'INITIAL_SESSION' | 'SIGNED_IN' | 'SIGNED_OUT' | 'TOKEN_REFRESHED';

/**
 * Auth state change callback data.
 *
 * @since 0.0.1
 */
export interface AuthStateChange {
  /**
   * The type of auth event.
   *
   * @since 0.0.1
   */
  event: AuthChangeEvent;

  /**
   * The current session (null if signed out).
   *
   * @since 0.0.1
   */
  session: Session | null;
}

/**
 * Options for database select queries.
 *
 * @since 0.0.1
 */
export interface SelectOptions {
  /**
   * The table name to query.
   *
   * @since 0.0.1
   */
  table: string;

  /**
   * Columns to select (default: "*").
   *
   * @since 0.0.1
   */
  columns?: string;

  /**
   * Filter conditions as key-value pairs. Each pair matches rows where the
   * column equals the value.
   *
   * @since 0.0.1
   */
  filter?: Record<string, unknown>;

  /**
   * Maximum number of rows to return.
   *
   * @since 0.0.1
   */
  limit?: number;

  /**
   * Number of rows to skip.
   *
   * @since 0.0.1
   */
  offset?: number;

  /**
   * Column to order by.
   *
   * @since 0.0.1
   */
  orderBy?: string;

  /**
   * Order direction.
   *
   * @since 0.0.1
   */
  ascending?: boolean;

  /**
   * Return a single row instead of an array.
   *
   * @since 0.0.1
   */
  single?: boolean;
}

/**
 * Options for database insert queries.
 *
 * @since 0.0.1
 */
export interface InsertOptions {
  /**
   * The table name to insert into.
   *
   * @since 0.0.1
   */
  table: string;

  /**
   * The data to insert (single object or array of objects).
   *
   * @since 0.0.1
   */
  values: Record<string, unknown> | Record<string, unknown>[];
}

/**
 * Options for database update queries.
 *
 * @since 0.0.1
 */
export interface UpdateOptions {
  /**
   * The table name to update.
   *
   * @since 0.0.1
   */
  table: string;

  /**
   * The data to update.
   *
   * @since 0.0.1
   */
  values: Record<string, unknown>;

  /**
   * Filter conditions to match rows to update.
   *
   * @since 0.0.1
   */
  filter: Record<string, unknown>;
}

/**
 * Options for database delete queries.
 *
 * @since 0.0.1
 */
export interface DeleteOptions {
  /**
   * The table name to delete from.
   *
   * @since 0.0.1
   */
  table: string;

  /**
   * Filter conditions to match rows to delete.
   *
   * @since 0.0.1
   */
  filter: Record<string, unknown>;
}

/**
 * Result of database queries.
 *
 * @since 0.0.1
 */
export interface QueryResult<T = unknown> {
  /**
   * The query result data.
   *
   * @since 0.0.1
   */
  data: T | null;

  /**
   * Error message if the query failed.
   *
   * @since 0.0.1
   */
  error: string | null;

  /**
   * Number of affected rows (for insert/update/delete).
   *
   * @since 0.0.1
   */
  count?: number;
}

/**
 * Capacitor Neon Plugin for native Neon Auth and Data API integration.
 *
 * This plugin runs Neon Auth sign-in natively on iOS and Android, keeps the
 * session in secure native storage, and gives you JWT tokens for use in
 * JavaScript/web layers.
 *
 * @since 0.0.1
 */
export interface CapacitorNeonPlugin {
  /**
   * Initialize the Neon client with your branch URLs.
   * Must be called before any other methods. Restores a stored session and
   * emits `INITIAL_SESSION`.
   *
   * @param options - Neon Auth URL and optional Data API URL
   * @returns Promise that resolves when initialization is complete
   * @throws Error if initialization fails
   * @since 0.0.1
   * @example
   * ```typescript
   * await CapacitorNeon.initialize({
   *   authUrl: 'https://ep-xxx.neonauth.us-east-2.aws.neon.tech/neondb/auth',
   *   dataApiUrl: 'https://ep-xxx.apirest.us-east-2.aws.neon.tech/neondb/rest/v1'
   * });
   * ```
   */
  initialize(options: NeonConfig): Promise<void>;

  /**
   * Sign in with email and password.
   *
   * @param options - Email and password credentials
   * @returns Promise with session and user data
   * @throws Error if sign-in fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session, user } = await CapacitorNeon.signInWithPassword({
   *   email: 'user@example.com',
   *   password: 'password123'
   * });
   * console.log('JWT:', session?.accessToken);
   * ```
   */
  signInWithPassword(options: SignInWithPasswordOptions): Promise<AuthResult>;

  /**
   * Sign up a new user with email and password.
   *
   * @param options - Email, password, and optional name and image
   * @returns Promise with session and user data
   * @throws Error if sign-up fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session, user } = await CapacitorNeon.signUp({
   *   email: 'newuser@example.com',
   *   password: 'password123',
   *   name: 'John Doe'
   * });
   * ```
   */
  signUp(options: SignUpOptions): Promise<AuthResult>;

  /**
   * Get an anonymous Data API token.
   * Neon Auth has no anonymous user accounts. This token lets signed-out users
   * query the Data API as the `anonymous` Postgres role, so RLS policies for
   * that role apply. Database methods use it automatically when no one is
   * signed in.
   *
   * @returns Promise with the anonymous JWT and its expiry
   * @throws Error if fetching the token fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { token } = await CapacitorNeon.getAnonymousToken();
   * ```
   */
  getAnonymousToken(): Promise<AnonymousToken>;

  /**
   * Sign in with an OAuth provider.
   * Opens the provider's authentication page in the system browser. When your
   * app reopens at `redirectTo`, the plugin completes sign-in and emits
   * `SIGNED_IN`.
   *
   * @param options - OAuth provider and redirect URL
   * @returns Promise that resolves when OAuth flow is initiated
   * @throws Error if OAuth sign-in fails
   * @since 0.0.1
   * @example
   * ```typescript
   * await CapacitorNeon.signInWithOAuth({
   *   provider: 'google',
   *   redirectTo: 'https://app.example.com/auth/callback'
   * });
   * ```
   */
  signInWithOAuth(options: SignInWithOAuthOptions): Promise<void>;

  /**
   * Sign in with OTP (One-Time Password) sent via email.
   *
   * @param options - Email address to send OTP to
   * @returns Promise that resolves when OTP is sent
   * @throws Error if sending OTP fails
   * @since 0.0.1
   * @example
   * ```typescript
   * await CapacitorNeon.signInWithOtp({
   *   email: 'user@example.com'
   * });
   * ```
   */
  signInWithOtp(options: SignInWithOtpOptions): Promise<void>;

  /**
   * Verify an OTP token.
   *
   * @param options - Email, token, and verification type
   * @returns Promise with session and user data
   * @throws Error if verification fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session, user } = await CapacitorNeon.verifyOtp({
   *   email: 'user@example.com',
   *   token: '123456',
   *   type: 'email'
   * });
   * ```
   */
  verifyOtp(options: VerifyOtpOptions): Promise<AuthResult>;

  /**
   * Sign out the current user.
   *
   * @returns Promise that resolves when sign-out is complete
   * @throws Error if sign-out fails
   * @since 0.0.1
   * @example
   * ```typescript
   * await CapacitorNeon.signOut();
   * ```
   */
  signOut(): Promise<void>;

  /**
   * Get the current session if one exists.
   * Returns the session with JWT access token, minting a new one when the
   * cached token is close to expiry.
   *
   * @returns Promise with the current session or null
   * @throws Error if retrieving session fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session } = await CapacitorNeon.getSession();
   * if (session) {
   *   console.log('JWT:', session.accessToken);
   * }
   * ```
   */
  getSession(): Promise<{ session: Session | null }>;

  /**
   * Refresh the current session and get a new access token.
   *
   * @returns Promise with the refreshed session
   * @throws Error if refresh fails or no session exists
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session } = await CapacitorNeon.refreshSession();
   * console.log('New JWT:', session?.accessToken);
   * ```
   */
  refreshSession(): Promise<{ session: Session | null }>;

  /**
   * Get the currently authenticated user.
   *
   * @returns Promise with the current user or null
   * @throws Error if retrieving user fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { user } = await CapacitorNeon.getUser();
   * if (user) {
   *   console.log('User ID:', user.id);
   * }
   * ```
   */
  getUser(): Promise<{ user: User | null }>;

  /**
   * Set the session manually from a refresh token.
   * Useful for restoring a session or integrating with external auth.
   *
   * @param options - Refresh token and optional access token
   * @returns Promise with the restored session
   * @throws Error if setting session fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { session } = await CapacitorNeon.setSession({
   *   refreshToken: 'abc123.signature'
   * });
   * ```
   */
  setSession(options: SetSessionOptions): Promise<{ session: Session | null }>;

  /**
   * Listen to authentication state changes.
   *
   * @param eventName - Must be 'authStateChange'
   * @param listenerFunc - Callback function for auth state changes
   * @returns Promise with handle to remove the listener
   * @since 0.0.1
   * @example
   * ```typescript
   * const listener = await CapacitorNeon.addListener(
   *   'authStateChange',
   *   ({ event, session }) => {
   *     console.log('Auth event:', event);
   *     if (session) {
   *       console.log('JWT:', session.accessToken);
   *     }
   *   }
   * );
   *
   * // Later, remove the listener
   * listener.remove();
   * ```
   */
  addListener(
    eventName: 'authStateChange',
    listenerFunc: (data: AuthStateChange) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Remove all listeners for auth state changes.
   *
   * @since 0.0.1
   * @example
   * ```typescript
   * await CapacitorNeon.removeAllListeners();
   * ```
   */
  removeAllListeners(): Promise<void>;

  /**
   * Execute a SELECT query on a table through the Neon Data API.
   *
   * @param options - Query options including table, columns, filters
   * @returns Promise with query results
   * @throws Error if query fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { data, error } = await CapacitorNeon.select({
   *   table: 'users',
   *   columns: 'id, name, email',
   *   filter: { active: true },
   *   limit: 10,
   *   orderBy: 'created_at',
   *   ascending: false
   * });
   * ```
   */
  select<T = unknown>(options: SelectOptions): Promise<QueryResult<T[]>>;

  /**
   * Insert data into a table through the Neon Data API.
   *
   * @param options - Table name and values to insert
   * @returns Promise with inserted data
   * @throws Error if insert fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { data, error } = await CapacitorNeon.insert({
   *   table: 'posts',
   *   values: { title: 'Hello', content: 'World' }
   * });
   * ```
   */
  insert<T = unknown>(options: InsertOptions): Promise<QueryResult<T>>;

  /**
   * Update data in a table through the Neon Data API.
   *
   * @param options - Table name, values to update, and filter conditions
   * @returns Promise with updated data
   * @throws Error if update fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { data, error } = await CapacitorNeon.update({
   *   table: 'posts',
   *   values: { title: 'Updated Title' },
   *   filter: { id: 1 }
   * });
   * ```
   */
  update<T = unknown>(options: UpdateOptions): Promise<QueryResult<T>>;

  /**
   * Delete data from a table through the Neon Data API.
   *
   * @param options - Table name and filter conditions
   * @returns Promise with deleted data
   * @throws Error if delete fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { data, error } = await CapacitorNeon.delete({
   *   table: 'posts',
   *   filter: { id: 1 }
   * });
   * ```
   */
  delete<T = unknown>(options: DeleteOptions): Promise<QueryResult<T>>;

  /**
   * Get the native Capacitor plugin version.
   *
   * @returns Promise that resolves with the plugin version
   * @throws Error if getting the version fails
   * @since 0.0.1
   * @example
   * ```typescript
   * const { version } = await CapacitorNeon.getPluginVersion();
   * console.log('Plugin version:', version);
   * ```
   */
  getPluginVersion(): Promise<{ version: string }>;
}
