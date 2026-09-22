import { http } from '@kit.NetworkKit';
import { RemoteAssignment } from './RemoteModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

export interface RemoteVoiceMaterialAutoCreateResponse {
  created: boolean;
  businessDate: string;
  packageId: string;
  assignmentId: string;
  assignment: RemoteAssignment | null;
}

export class RemoteVoiceMaterialApi {
  static readonly instance: RemoteVoiceMaterialApi = new RemoteVoiceMaterialApi();
  private constructor() {}

  async autoCreateNext(studentId: string): Promise<RemoteVoiceMaterialAutoCreateResponse> {
    if (!BackendSession.instance.isConnected()) {
      return {
        created: false,
        businessDate: '',
        packageId: '',
        assignmentId: '',
        assignment: null
      };
    }
    let path =
      `/api/v1/students/${encodeURIComponent(studentId)}/voice-material-packages/auto-create-next`;
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.auto-create', path, http.RequestMethod.POST);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`自动创建语音任务失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteVoiceMaterialAutoCreateResponse;
  }
}
