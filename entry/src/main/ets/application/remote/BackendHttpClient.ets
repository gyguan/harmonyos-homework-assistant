import { http } from '@kit.NetworkKit';
import { BackendSession } from './BackendSession';

export interface BackendResponse {
  statusCode: number;
  body: string;
}

export class BackendHttpClient {
  static readonly instance: BackendHttpClient = new BackendHttpClient();
  private constructor() {}

  async request(path: string, method: http.RequestMethod, body: Object | null = null, authenticated: boolean = true): Promise<BackendResponse> {
    let session = BackendSession.instance;
    if (session.getBaseUrl().length === 0) throw new Error('请先配置后端地址');
    let headers: Record<string, string> = { 'Content-Type': 'application/json' };
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
}
