import { http } from '@kit.NetworkKit';
import { BackendSession } from './BackendSession';

export interface BackendResponse {
  statusCode: number;
  body: string;
}

export class BackendHttpClient {
  static readonly instance: BackendHttpClient = new BackendHttpClient();
  private requestSequence: number = 0;
  private constructor() {}

  async requestFor(scene: string, path: string, method: http.RequestMethod,
    body: Object | null = null, authenticated: boolean = true): Promise<BackendResponse> {
    return this.request(path, method, body, authenticated, scene);
  }

  traceHeaders(path: string, method: http.RequestMethod, scene: string): Record<string, string> {
    this.requestSequence++;
    let requestId = `harmony-${Date.now()}-${this.requestSequence}`;
    return {
      'X-Request-Id': requestId,
      'X-Client-Scene': this.safeScene(scene),
      'X-Client-Request-Key': encodeURIComponent(`${method}|${path}`)
    };
  }

  async request(path: string, method: http.RequestMethod, body: Object | null = null,
    authenticated: boolean = true, scene: string = 'unclassified'): Promise<BackendResponse> {
    let session = BackendSession.instance;
    if (session.getBaseUrl().length === 0) throw new Error('请先配置后端地址');
    let headers: Record<string, string> = this.traceHeaders(path, method, scene);
    headers['Content-Type'] = 'application/json';
    if (authenticated) {
      if (!session.isConnected()) throw new Error('请先登录后端');
      headers['Authorization'] = `Bearer ${session.getToken()}`;
    }
    let client = http.createHttp();
    try {
      let options: http.HttpRequestOptions = { method: method, header: headers };
      if (body !== null) options.extraData = JSON.stringify(body);
      let response = await client.request(session.getBaseUrl() + path, options);
      if (authenticated && response.responseCode === 401) session.disconnect();
      let text = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return { statusCode: response.responseCode, body: text };
    } catch {
      throw new Error('后端请求失败，请检查网络或后端地址');
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  private safeScene(value: string): string {
    let normalized = value.trim();
    if (normalized.length === 0) return 'unclassified';
    if (normalized.length > 80) normalized = normalized.substring(0, 80);
    return normalized;
  }
}
