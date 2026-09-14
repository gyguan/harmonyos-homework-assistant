export class BackendSession {
  static readonly instance: BackendSession = new BackendSession();
  private baseUrl: string = '';
  private token: string = '';

  private constructor() {}

  connect(baseUrl: string, token: string): void {
    this.baseUrl = this.normalize(baseUrl);
    this.token = token;
  }

  disconnect(): void {
    this.token = '';
  }

  isConnected(): boolean {
    return this.baseUrl.length > 0 && this.token.length > 0;
  }

  getBaseUrl(): string { return this.baseUrl; }
  getToken(): string { return this.token; }

  private normalize(value: string): string {
    let result = value.trim();
    while (result.endsWith('/')) result = result.substring(0, result.length - 1);
    return result;
  }
}
