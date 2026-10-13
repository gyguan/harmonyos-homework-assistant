import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';

export interface FamilyAccountItem {
  id: string;
  loginName: string;
  displayName: string;
  mine: boolean;
}

interface FamilyAccountListResponse {
  accounts: FamilyAccountItem[];
}

interface FamilyAccountCreateRequest {
  loginName: string;
  password: string;
  displayName: string;
}

interface FamilyAccountUpdateMineRequest {
  displayName: string;
}

export class FamilyAccountRemoteApi {
  static readonly instance: FamilyAccountRemoteApi = new FamilyAccountRemoteApi();
  private constructor() {}

  async list(): Promise<FamilyAccountItem[]> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.accounts.list', '/api/v1/auth/family-accounts', http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('家庭家长账号加载失败');
    }
    let parsed = JSON.parse(response.body) as FamilyAccountListResponse;
    return parsed.accounts.slice();
  }

  async updateMineDisplayName(displayName: string): Promise<FamilyAccountItem> {
    let payload: FamilyAccountUpdateMineRequest = { displayName: displayName.trim() };
    let response = await BackendHttpClient.instance.requestFor(
      'family.accounts.updateMine', '/api/v1/auth/family-accounts/me', http.RequestMethod.PUT, payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('显示名称修改失败');
    }
    return JSON.parse(response.body) as FamilyAccountItem;
  }

  async create(loginName: string, displayName: string, password: string): Promise<FamilyAccountItem> {
    let payload: FamilyAccountCreateRequest = {
      loginName: loginName.trim(),
      password: password,
      displayName: displayName.trim()
    };
    let response = await BackendHttpClient.instance.requestFor(
      'family.accounts.create', '/api/v1/auth/family-accounts', http.RequestMethod.POST, payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      let detail = response.body.indexOf('登录名已存在') >= 0 ? '登录名已存在' : '新增家长账号失败';
      throw new Error(detail);
    }
    return JSON.parse(response.body) as FamilyAccountItem;
  }
}
