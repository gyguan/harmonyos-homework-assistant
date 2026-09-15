import { common } from '@kit.AbilityKit';
import { BusinessError, request } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

export interface RemoteSubmissionPhoto {
  id: string;
  originalName: string;
  contentType: string;
  sizeBytes: number;
  downloadPath: string;
}

export interface RemoteSubmission {
  id: string;
  assignmentId: string;
  submittedAt: string;
  photos: RemoteSubmissionPhoto[];
}

export class RemoteSubmissionApi {
  static readonly instance: RemoteSubmissionApi = new RemoteSubmissionApi();
  private context: common.UIAbilityContext | null = null;
  private photoCache: Map<string, string> = new Map<string, string>();
  private constructor() {}
  configure(context: common.UIAbilityContext): void { this.context = context; }

  async list(assignmentId: string): Promise<RemoteSubmission[]> {
    if (!BackendSession.instance.isConnected()) return [];
    let response = await BackendHttpClient.instance.request(
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/submissions`, http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error('读取云端提交记录失败');
    return JSON.parse(response.body) as RemoteSubmission[];
  }

  cachedPhotoUri(photoId: string): string {
    let cached = this.photoCache.get(photoId);
    return cached === undefined ? '' : cached;
  }

  async downloadPhoto(photo: RemoteSubmissionPhoto): Promise<string> {
    let cached = this.cachedPhotoUri(photo.id);
    if (cached.length > 0) return cached;
    if (this.context === null || !BackendSession.instance.isConnected()) return '';

    let client = http.createHttp();
    try {
      let response = await client.request(
        `${BackendSession.instance.getBaseUrl()}/api/v1/submission-photos/${encodeURIComponent(photo.id)}`,
        {
          method: http.RequestMethod.GET,
          header: { 'Authorization': `Bearer ${BackendSession.instance.getToken()}` },
          connectTimeout: 10000,
          readTimeout: 20000,
          maxLimit: 15 * 1024 * 1024,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        });
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        return '';
      }
      if (response.responseCode !== http.ResponseCode.OK) return '';

      let data = response.result as ArrayBuffer;
      if (data.byteLength === 0) return '';
      let cachePath = `${this.context.cacheDir}/submission-photo-${photo.id}.${this.extension(photo.contentType)}`;
      let file = await fileIo.open(cachePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, data);
      } finally {
        try { await fileIo.close(file); } catch {}
      }
      let uri = fileUri.getUriFromPath(cachePath);
      this.photoCache.set(photo.id, uri);
      return uri;
    } catch {
      return '';
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  async upload(assignmentId: string, sourceUris: string[]): Promise<boolean> {
    if (this.context === null || !BackendSession.instance.isConnected() || sourceUris.length === 0) return false;
    let uploadFiles: request.File[] = [];
    let cachePaths: string[] = [];
    try {
      for (let i = 0; i < sourceUris.length; i++) {
        let fileName = `homework-upload-${Date.now()}-${i + 1}.jpg`;
        let cachePath = `${this.context.cacheDir}/${fileName}`;
        let source = await fileIo.open(sourceUris[i], fileIo.OpenMode.READ_ONLY);
        try {
          await fileIo.copyFile(source.fd, cachePath, 0);
        } finally {
          try { await fileIo.close(source); } catch {}
        }
        cachePaths.push(cachePath);
        uploadFiles.push({ filename: fileName, name: 'photos', uri: `internal://cache/${fileName}`, type: 'jpg' });
      }
      let config: request.UploadConfig = {
        url: `${BackendSession.instance.getBaseUrl()}/api/v1/assignments/${encodeURIComponent(assignmentId)}/submissions`,
        header: { 'Authorization': `Bearer ${BackendSession.instance.getToken()}` },
        method: 'POST', files: uploadFiles, data: []
      };
      let task = await request.uploadFile(this.context, config);
      return await new Promise<boolean>((resolve) => {
        task.on('complete', (_states: request.TaskState[]) => resolve(true));
        task.on('fail', (_states: request.TaskState[]) => resolve(false));
      });
    } catch (error) {
      let _businessError = error as BusinessError;
      return false;
    } finally {
      for (let path of cachePaths) {
        try { await fileIo.unlink(path); } catch {}
      }
    }
  }

  private extension(contentType: string): string {
    let normalized = contentType.toLowerCase();
    if (normalized.indexOf('png') >= 0) return 'png';
    if (normalized.indexOf('webp') >= 0) return 'webp';
    return 'jpg';
  }
}
