export interface StoredBackendSession {
  baseUrl: string;
  token: string;
  displayName: string;
}

export interface BackendSessionStorage {
  load(): Promise<StoredBackendSession | null>;
  save(session: StoredBackendSession): Promise<void>;
  clear(): Promise<void>;
}
