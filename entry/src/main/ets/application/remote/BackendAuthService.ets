import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

interface LoginPayload { loginName: string; password: string; }
interface LoginResult { token: string; displayName: string; }
interface SessionResult { displayName: string; }

export class BackendAuthService {
  static readonly instance: BackendAuthService = new BackendAuthService();
  private constructor() {}

  async login(baseUrl: string, loginName: string, password: string): Promise<string> {
    BackendSession.instance.prepare(baseUrl);
    let payload: LoginPayload = { loginName: loginName.trim(), password: password };
    let response = await BackendHttpClient.instance.requestFor(
      'auth.login', '/api/v1/auth/login', http.RequestMethod.POST, payload, false);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      BackendSession.instance.disconnect();
      throw new Error('登录失败，请检查后端地址、账号和密码');
    }
    // 网关/Captive Portal 会返回 HTML 或空串，JSON.parse 一抛异常就变成"点了没反应"。
    let parsed: LoginResult;
    try {
      parsed = JSON.parse(response.body) as LoginResult;
    } catch {
      BackendSession.instance.disconnect();
      throw new Error('登录返回的内容不是合法数据，请确认服务地址指向小伴作业后端');
    }
    if (typeof parsed.token !== 'string' || parsed.token.length === 0) {
      BackendSession.instance.disconnect();
      throw new Error('登录返回的内容缺少登录凭证，请重新连接');
    }
    BackendSession.instance.connect(baseUrl, parsed.token, parsed.displayName);
    return parsed.displayName;
  }

  async validateSession(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      let response = await BackendHttpClient.instance.requestFor(
        'auth.session', '/api/v1/auth/session', http.RequestMethod.GET);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      let parsed: SessionResult = JSON.parse(response.body) as SessionResult;
      BackendSession.instance.connect(BackendSession.instance.getBaseUrl(), BackendSession.instance.getToken(), parsed.displayName);
      return true;
    } catch {
      return false;
    }
  }

  async logout(): Promise<void> {
    try {
      if (BackendSession.instance.isConnected()) {
        await BackendHttpClient.instance.requestFor(
          'auth.logout', '/api/v1/auth/logout', http.RequestMethod.POST);
      }
    } catch {} finally {
      BackendSession.instance.disconnect();
    }
  }
}
