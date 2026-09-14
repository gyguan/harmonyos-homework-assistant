import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BackendSessionStorage, StoredBackendSession } from '../../domain/port/BackendSessionStorage';

const STORE_NAME: string = 'homework_backend_session';
const SESSION_KEY: string = 'backend_session_v1';

export class PreferencesBackendSessionStorage implements BackendSessionStorage {
  private readonly context: common.UIAbilityContext;
  private store: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) { this.context = context; }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store === null) this.store = await preferences.getPreferences(this.context, STORE_NAME);
    return this.store;
  }

  async load(): Promise<StoredBackendSession | null> {
    try {
      let store = await this.getStore();
      let value = await store.get(SESSION_KEY, '');
      if (typeof value !== 'string' || value.length === 0) return null;
      let parsed: Record<string, Object> = JSON.parse(value);
      return {
        baseUrl: parsed.baseUrl as string,
        token: parsed.token as string,
        displayName: parsed.displayName as string
      };
    } catch {
      return null;
    }
  }

  async save(session: StoredBackendSession): Promise<void> {
    try {
      let store = await this.getStore();
      await store.put(SESSION_KEY, JSON.stringify(session));
      await store.flush();
    } catch {}
  }

  async clear(): Promise<void> {
    try {
      let store = await this.getStore();
      await store.delete(SESSION_KEY);
      await store.flush();
    } catch {}
  }
}
