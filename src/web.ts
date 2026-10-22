import { WebPlugin } from '@capacitor/core';

import type {
  AnonymousToken,
  AuthResult,
  AuthStateChange,
  CapacitorNeonPlugin,
  DeleteOptions,
  InsertOptions,
  QueryResult,
  SelectOptions,
  Session,
  SetSessionOptions,
  SignInWithOAuthOptions,
  SignInWithOtpOptions,
  SignInWithPasswordOptions,
  SignUpOptions,
  NeonConfig,
  UpdateOptions,
  User,
  VerifyOtpOptions,
} from './definitions';

export class CapacitorNeonWeb extends WebPlugin implements CapacitorNeonPlugin {
  async initialize(_options: NeonConfig): Promise<void> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async signInWithPassword(_options: SignInWithPasswordOptions): Promise<AuthResult> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async signUp(_options: SignUpOptions): Promise<AuthResult> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async getAnonymousToken(): Promise<AnonymousToken> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async signInWithOAuth(_options: SignInWithOAuthOptions): Promise<void> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async signInWithOtp(_options: SignInWithOtpOptions): Promise<void> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async verifyOtp(_options: VerifyOtpOptions): Promise<AuthResult> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async signOut(): Promise<void> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async getSession(): Promise<{ session: Session | null }> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async refreshSession(): Promise<{ session: Session | null }> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async getUser(): Promise<{ user: User | null }> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async setSession(_options: SetSessionOptions): Promise<{ session: Session | null }> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async select<T = unknown>(_options: SelectOptions): Promise<QueryResult<T[]>> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async insert<T = unknown>(_options: InsertOptions): Promise<QueryResult<T>> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async update<T = unknown>(_options: UpdateOptions): Promise<QueryResult<T>> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async delete<T = unknown>(_options: DeleteOptions): Promise<QueryResult<T>> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  override async addListener(
    _eventName: 'authStateChange',

    _listenerFunc: (data: AuthStateChange) => void,
  ): Promise<{ remove: () => Promise<void> }> {
    throw new Error('Web implementation not available. Use @neondatabase/neon-js directly for web.');
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: 'web' };
  }
}
