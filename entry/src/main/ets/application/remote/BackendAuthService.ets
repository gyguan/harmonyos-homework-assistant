import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

interface LoginPayload { loginName: string; password: string; }
interface LoginResult { token: string; displayName: string; }

export class BackendAuthService {
  static readonly instance: BackendAuthService = new BackendAuthService();
  private constructor() {}

  async login(baseUrl: string, loginName: string, password: string): Promise<string> {
    BackendSession.instance.connect(baseUrl, 'pending');
    let payload: LoginPayload = { loginName: loginName.trim(), password: password };
    let response = await BackendHttpClient.instance.request('/api/v1/auth/login', http.RequestMethod.POST, payload, false);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      BackendSession.instance.disconnect();
      throw new Error('登录失败，请检查后端地址、账号和密码');
    }
    let parsed: LoginResult = JSON.parse(response.body) as LoginResult;
    BackendSession.instance.connect(baseUrl, parsed.token);
    return parsed.displayName;
  }
}
