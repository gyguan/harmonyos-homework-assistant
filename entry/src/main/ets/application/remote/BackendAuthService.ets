import { http } from '@kit.NetworkKit';
import { AppConfig } from '../../common/config/AppConfig';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

interface LoginPayload { loginName: string; password: string; }
interface LoginResult { token: string; displayName: string; }
interface SessionResult { displayName: string; }

export enum SessionState {
  OK = 'OK',
  UNAUTHORIZED = 'UNAUTHORIZED',
  UNREACHABLE = 'UNREACHABLE'
}

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
      throw new Error('登录失败，请确认服务地址与服务器上的默认家长账号一致');
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

  /**
   * 默认账号登录：家庭版只有一个家长身份，家长不需要再输入用户名密码。
   * 账号来自 AppConfig，与服务器 .env 的 BOOTSTRAP_LOGIN / BOOTSTRAP_PASSWORD 一致。
   */
  async loginWithDefaults(baseUrl: string): Promise<string> {
    return this.login(baseUrl, AppConfig.PARENT_LOGIN, AppConfig.PARENT_PASSWORD);
  }

  /**
   * 区分「登录失效」和「网络不可达」：
   * 失效可以用默认账号静默重登；不可达必须保留本地令牌，否则离线打开会把有效登录态丢掉。
   * 注意 401 时 BackendHttpClient 已经主动 disconnect，baseUrl 仍然保留，重登可直接复用。
   */
  async sessionState(): Promise<SessionState> {
    if (!BackendSession.instance.isConnected()) return SessionState.UNAUTHORIZED;
    try {
      let response = await BackendHttpClient.instance.requestFor(
        'auth.session', '/api/v1/auth/session', http.RequestMethod.GET);
      if (response.statusCode === 401 || response.statusCode === 403) return SessionState.UNAUTHORIZED;
      if (response.statusCode < 200 || response.statusCode >= 300) return SessionState.UNREACHABLE;
      let parsed: SessionResult = JSON.parse(response.body) as SessionResult;
      BackendSession.instance.connect(BackendSession.instance.getBaseUrl(), BackendSession.instance.getToken(), parsed.displayName);
      return SessionState.OK;
    } catch {
      return SessionState.UNREACHABLE;
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
