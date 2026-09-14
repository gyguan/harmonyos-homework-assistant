import { BackendSessionStorage } from '../../domain/port/BackendSessionStorage';

export class BackendSession {
  static readonly instance: BackendSession = new BackendSession();
  private baseUrl: string = '';
  private token: string = '';
  private displayName: string = '';
  private storage: BackendSessionStorage | null = null;

  private constructor() {}

  async initialize(storage: BackendSessionStorage): Promise<void> {
    this.storage = storage;
    let saved = await storage.load();
    if (saved === null) return;
    this.baseUrl = this.normalize(saved.baseUrl);
    this.token = saved.token;
    this.displayName = saved.displayName;
  }

  prepare(baseUrl: string): void {
    this.baseUrl = this.normalize(baseUrl);
    this.token = '';
    this.displayName = '';
  }

  connect(baseUrl: string, token: string, displayName: string = ''): void {
    this.baseUrl = this.normalize(baseUrl);
    this.token = token;
    this.displayName = displayName;
    if (this.storage !== null) {
      void this.storage.save({ baseUrl: this.baseUrl, token: this.token, displayName: this.displayName });
    }
  }

  disconnect(): void {
    this.token = '';
    this.displayName = '';
    if (this.storage !== null) void this.storage.clear();
  }

  isConnected(): boolean { return this.baseUrl.length > 0 && this.token.length > 0; }
  getBaseUrl(): string { return this.baseUrl; }
  getToken(): string { return this.token; }
  getDisplayName(): string { return this.displayName; }

  private normalize(value: string): string {
    let result = value.trim();
    while (result.endsWith('/')) result = result.substring(0, result.length - 1);
    return result;
  }
}
