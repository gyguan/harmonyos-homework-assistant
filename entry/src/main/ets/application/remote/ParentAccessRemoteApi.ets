import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';

export interface ParentAccessStatus {
  enabled: boolean;
}

interface ParentAccessCodeRequest {
  code: string;
}

interface ParentAccessVerifyResponse {
  valid: boolean;
}

export class ParentAccessRemoteApi {
  static readonly instance: ParentAccessRemoteApi = new ParentAccessRemoteApi();
  private constructor() {}

  async status(): Promise<ParentAccessStatus> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.parentAccess.status',
      '/api/v1/family/parent-access',
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('家长码状态加载失败');
    }
    return JSON.parse(response.body) as ParentAccessStatus;
  }

  async setCode(code: string): Promise<ParentAccessStatus> {
    let payload: ParentAccessCodeRequest = { code: code };
    let response = await BackendHttpClient.instance.requestFor(
      'family.parentAccess.set',
      '/api/v1/family/parent-access',
      http.RequestMethod.PUT,
      payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('家长码保存失败');
    }
    return JSON.parse(response.body) as ParentAccessStatus;
  }

  async clear(): Promise<ParentAccessStatus> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.parentAccess.clear',
      '/api/v1/family/parent-access',
      http.RequestMethod.DELETE);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('关闭家长码失败');
    }
    return JSON.parse(response.body) as ParentAccessStatus;
  }

  async verify(code: string): Promise<boolean> {
    let payload: ParentAccessCodeRequest = { code: code };
    let response = await BackendHttpClient.instance.requestFor(
      'family.parentAccess.verify',
      '/api/v1/family/parent-access/verify',
      http.RequestMethod.POST,
      payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('家长码验证失败');
    }
    let parsed = JSON.parse(response.body) as ParentAccessVerifyResponse;
    return parsed.valid;
  }
}
