import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { RemoteAssignment } from './RemoteModels';

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

export interface RemoteSubmissionCreateResponse {
  submission: RemoteSubmission;
  assignment: RemoteAssignment;
}

interface MultipartPayload {
  boundary: string;
  body: ArrayBuffer;
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

  async upload(assignmentId: string, version: number,
    sourceUris: string[]): Promise<RemoteSubmissionCreateResponse> {
    if (this.context === null) throw new Error('SUBMISSION_CONTEXT_MISSING');
    if (!BackendSession.instance.isConnected()) throw new Error('SUBMISSION_OFFLINE');
    if (version < 0) throw new Error('SUBMISSION_VERSION_MISSING');
    if (sourceUris.length === 0 || sourceUris.length > 6) throw new Error('SUBMISSION_PHOTO_COUNT');

    let payload = await this.buildMultipartPayload(sourceUris);
    let client = http.createHttp();
    try {
      let response: http.HttpResponse;
      try {
        response = await client.request(
          `${BackendSession.instance.getBaseUrl()}/api/v1/assignments/${encodeURIComponent(assignmentId)}` +
            `/submissions?version=${version}`,
          {
            method: http.RequestMethod.POST,
            header: {
              'Authorization': `Bearer ${BackendSession.instance.getToken()}`,
              'Content-Type': `multipart/form-data; boundary=${payload.boundary}`
            },
            extraData: payload.body,
            connectTimeout: 15000,
            readTimeout: 60000
          });
      } catch {
        throw new Error('SUBMISSION_NETWORK_ERROR');
      }
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        throw new Error('SUBMISSION_UNAUTHORIZED');
      }
      if (response.responseCode === 409) throw new Error('REMOTE_CONFLICT');
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`SUBMISSION_HTTP_${response.responseCode}`);
      }
      let text = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return JSON.parse(text) as RemoteSubmissionCreateResponse;
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  private async buildMultipartPayload(sourceUris: string[]): Promise<MultipartPayload> {
    if (this.context === null) throw new Error('上传上下文未初始化');
    let boundary = `----xiaoban-homework-${Date.now()}`;
    let multipartPath = `${this.context.cacheDir}/submission-multipart-${Date.now()}.bin`;

    try {
      let writer = await fileIo.open(multipartPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      let totalBytes = 0;
      try {
        for (let i = 0; i < sourceUris.length; i++) {
          let fileName = `homework-upload-${i + 1}.jpg`;
          let header = `--${boundary}\r\nContent-Disposition: form-data; name="photos"; filename="${fileName}"\r\n` +
            'Content-Type: image/jpeg\r\n\r\n';
          totalBytes += await fileIo.write(writer.fd, header);

          let source = await fileIo.open(sourceUris[i], fileIo.OpenMode.READ_ONLY);
          try {
            let chunk = new ArrayBuffer(64 * 1024);
            while (true) {
              let readLength = await fileIo.read(source.fd, chunk);
              if (readLength <= 0) break;
              let written = await fileIo.write(writer.fd, chunk, { length: readLength });
              if (written !== readLength) throw new Error('作业照片写入 multipart 失败');
              totalBytes += written;
            }
          } finally {
            try { await fileIo.close(source); } catch {}
          }
          totalBytes += await fileIo.write(writer.fd, '\r\n');
        }
        totalBytes += await fileIo.write(writer.fd, `--${boundary}--\r\n`);
      } finally {
        try { await fileIo.close(writer); } catch {}
      }

      let body = new ArrayBuffer(totalBytes);
      let target = new Uint8Array(body);
      let reader = await fileIo.open(multipartPath, fileIo.OpenMode.READ_ONLY);
      let offset = 0;
      try {
        let chunk = new ArrayBuffer(64 * 1024);
        while (offset < totalBytes) {
          let readLength = await fileIo.read(reader.fd, chunk);
          if (readLength <= 0) break;
          target.set(new Uint8Array(chunk, 0, readLength), offset);
          offset += readLength;
        }
      } finally {
        try { await fileIo.close(reader); } catch {}
      }
      if (offset !== totalBytes) throw new Error('multipart 请求体读取不完整');
      return { boundary: boundary, body: body };
    } catch {
      throw new Error('构建作业照片上传请求失败');
    } finally {
      try { await fileIo.unlink(multipartPath); } catch {}
    }
  }

  private extension(contentType: string): string {
    let normalized = contentType.toLowerCase();
    if (normalized.indexOf('png') >= 0) return 'png';
    if (normalized.indexOf('webp') >= 0) return 'webp';
    return 'jpg';
  }
}
