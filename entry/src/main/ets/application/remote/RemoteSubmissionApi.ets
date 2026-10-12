import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { RemoteAssignment } from './RemoteModels';

export interface RemoteSubmissionResource {
  id: string;
  resourceType: string;
  originalName: string;
  contentType: string;
  sizeBytes: number;
  durationMs: number;
  sortOrder: number;
  downloadPath: string;
}

export interface RemoteSubmission {
  id: string;
  assignmentId: string;
  submittedAt: string;
  resources: RemoteSubmissionResource[];
}

export interface RemoteSubmissionCreateResponse {
  submission: RemoteSubmission;
  assignment: RemoteAssignment;
}

interface MultipartPayload {
  boundary: string;
  body: ArrayBuffer;
}

interface MultipartSource {
  fieldName: string;
  uri: string;
  fileName: string;
  contentType: string;
}

export class RemoteSubmissionApi {
  static readonly instance: RemoteSubmissionApi = new RemoteSubmissionApi();
  private context: common.UIAbilityContext | null = null;
  private resourceCache: Map<string, string> = new Map<string, string>();

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async list(assignmentId: string): Promise<RemoteSubmission[]> {
    if (!BackendSession.instance.isConnected()) return [];
    let response = await BackendHttpClient.instance.requestFor(
      'submission.history',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/submissions`,
      http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error('读取云端提交记录失败');
    return JSON.parse(response.body) as RemoteSubmission[];
  }

  async latest(assignmentId: string): Promise<RemoteSubmission | null> {
    if (!BackendSession.instance.isConnected()) return null;
    let response = await BackendHttpClient.instance.requestFor(
      'parent.review.evidence',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/submissions/latest`,
      http.RequestMethod.GET);
    if (response.statusCode === 204) return null;
    if (response.statusCode !== 200) throw new Error('读取最新提交记录失败');
    return JSON.parse(response.body) as RemoteSubmission;
  }

  cachedResourceUri(resourceId: string): string {
    let cached = this.resourceCache.get(resourceId);
    return cached === undefined ? '' : cached;
  }

  cachedPhotoUri(resourceId: string): string {
    return this.cachedResourceUri(resourceId);
  }

  async downloadResource(resource: RemoteSubmissionResource): Promise<string> {
    let cached = this.cachedResourceUri(resource.id);
    if (cached.length > 0) return cached;
    if (this.context === null || !BackendSession.instance.isConnected()) return '';

    let client = http.createHttp();
    try {
      let path = resource.downloadPath.length > 0 ?
        resource.downloadPath : `/api/v1/submission-resources/${encodeURIComponent(resource.id)}`;
      let headers = BackendHttpClient.instance.traceHeaders(
        path, http.RequestMethod.GET, 'submission.resource.download');
      headers['Authorization'] = `Bearer ${BackendSession.instance.getToken()}`;
      let response = await client.request(
        `${BackendSession.instance.getBaseUrl()}${path}`,
        {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: 10000,
          readTimeout: 30000,
          maxLimit: 25 * 1024 * 1024,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        });
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        return '';
      }
      if (response.responseCode !== http.ResponseCode.OK) return '';

      let data = response.result as ArrayBuffer;
      if (data.byteLength === 0) return '';
      let cachePath = `${this.context.cacheDir}/submission-resource-${resource.id}.${this.extension(resource)}`;
      let file = await fileIo.open(cachePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, data);
      } finally {
        try { await fileIo.close(file); } catch {}
      }
      let uri = fileUri.getUriFromPath(cachePath);
      this.resourceCache.set(resource.id, uri);
      return uri;
    } catch {
      return '';
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  async downloadPhoto(resource: RemoteSubmissionResource): Promise<string> {
    return await this.downloadResource(resource);
  }

  async uploadPhotos(
    assignmentId: string,
    version: number,
    sourceUris: string[]
  ): Promise<RemoteSubmissionCreateResponse> {
    if (sourceUris.length === 0 || sourceUris.length > 6) {
      throw new Error('SUBMISSION_PHOTO_COUNT');
    }
    let sources: MultipartSource[] = [];
    for (let i = 0; i < sourceUris.length; i++) {
      sources.push({
        fieldName: 'photos',
        uri: sourceUris[i],
        fileName: `homework-upload-${i + 1}.${this.imageExtension(sourceUris[i])}`,
        contentType: this.imageContentType(sourceUris[i])
      });
    }
    return await this.uploadMultipart(assignmentId, version, sources, 0);
  }

  async uploadAudio(
    assignmentId: string,
    version: number,
    sourceUri: string,
    durationMs: number
  ): Promise<RemoteSubmissionCreateResponse> {
    if (sourceUri.length === 0) throw new Error('SUBMISSION_AUDIO_MISSING');
    let source: MultipartSource = {
      fieldName: 'audio',
      uri: sourceUri,
      fileName: 'student-submission.m4a',
      contentType: 'audio/mp4'
    };
    return await this.uploadMultipart(assignmentId, version, [source], durationMs);
  }

  async upload(
    assignmentId: string,
    version: number,
    sourceUris: string[]
  ): Promise<RemoteSubmissionCreateResponse> {
    return await this.uploadPhotos(assignmentId, version, sourceUris);
  }

  private async uploadMultipart(
    assignmentId: string,
    version: number,
    sources: MultipartSource[],
    audioDurationMs: number
  ): Promise<RemoteSubmissionCreateResponse> {
    if (this.context === null) throw new Error('SUBMISSION_CONTEXT_MISSING');
    if (!BackendSession.instance.isConnected()) throw new Error('SUBMISSION_OFFLINE');
    if (version < 0) throw new Error('SUBMISSION_VERSION_MISSING');

    let payload = await this.buildMultipartPayload(sources);
    let client = http.createHttp();
    try {
      let response: http.HttpResponse;
      try {
        let path = `/api/v1/assignments/${encodeURIComponent(assignmentId)}/submissions?version=${version}` +
          `&audioDurationMs=${Math.max(0, Math.floor(audioDurationMs))}`;
        let headers = BackendHttpClient.instance.traceHeaders(
          path, http.RequestMethod.POST, 'submission.upload');
        headers['Authorization'] = `Bearer ${BackendSession.instance.getToken()}`;
        headers['Content-Type'] = `multipart/form-data; boundary=${payload.boundary}`;
        response = await client.request(
          `${BackendSession.instance.getBaseUrl()}${path}`,
          {
            method: http.RequestMethod.POST,
            header: headers,
            extraData: payload.body,
            connectTimeout: 15000,
            readTimeout: 90000
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
      let text = typeof response.result === 'string' ?
        response.result : JSON.stringify(response.result);
      return JSON.parse(text) as RemoteSubmissionCreateResponse;
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  private async buildMultipartPayload(sources: MultipartSource[]): Promise<MultipartPayload> {
    if (this.context === null) throw new Error('上传上下文未初始化');
    let boundary = `----xiaoban-submission-${Date.now()}`;
    let multipartPath = `${this.context.cacheDir}/submission-multipart-${Date.now()}.bin`;

    try {
      let writer = await fileIo.open(multipartPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      let totalBytes = 0;
      try {
        for (let sourceInfo of sources) {
          let header = `--${boundary}\r\nContent-Disposition: form-data; name="${sourceInfo.fieldName}"; filename="${sourceInfo.fileName}"\r\n` +
            `Content-Type: ${sourceInfo.contentType}\r\n\r\n`;
          totalBytes += await fileIo.write(writer.fd, header);
          let source = await fileIo.open(sourceInfo.uri, fileIo.OpenMode.READ_ONLY);
          try {
            let chunk = new ArrayBuffer(64 * 1024);
            while (true) {
              let readLength = await fileIo.read(source.fd, chunk);
              if (readLength <= 0) break;
              let written = await fileIo.write(writer.fd, chunk, { length: readLength });
              if (written !== readLength) throw new Error('提交资源写入 multipart 失败');
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
      throw new Error('构建作业提交请求失败');
    } finally {
      try { await fileIo.unlink(multipartPath); } catch {}
    }
  }

  private imageContentType(uri: string): string {
    let ext = this.imageExtension(uri);
    if (ext === 'png') return 'image/png';
    if (ext === 'webp') return 'image/webp';
    if (ext === 'heic') return 'image/heic';
    return 'image/jpeg';
  }

  private imageExtension(uri: string): string {
    let normalized = uri.toLowerCase();
    let queryIndex = normalized.indexOf('?');
    if (queryIndex >= 0) normalized = normalized.substring(0, queryIndex);
    let fragmentIndex = normalized.indexOf('#');
    if (fragmentIndex >= 0) normalized = normalized.substring(0, fragmentIndex);
    let dotIndex = normalized.lastIndexOf('.');
    let extension = dotIndex >= 0 && dotIndex < normalized.length - 1 ?
      normalized.substring(dotIndex + 1) : '';
    if (extension === 'png') return 'png';
    if (extension === 'webp') return 'webp';
    if (extension === 'heic' || extension === 'heif') return 'heic';
    if (extension === 'jpeg') return 'jpeg';
    return 'jpg';
  }

  private extension(resource: RemoteSubmissionResource): string {
    let normalized = resource.contentType.toLowerCase();
    if (normalized.indexOf('png') >= 0) return 'png';
    if (normalized.indexOf('webp') >= 0) return 'webp';
    if (normalized.indexOf('heic') >= 0 || normalized.indexOf('heif') >= 0) return 'heic';
    if (normalized.indexOf('wav') >= 0) return 'wav';
    if (normalized.indexOf('mpeg') >= 0 || normalized.indexOf('mp3') >= 0) return 'mp3';
    if (resource.resourceType === 'AUDIO') return 'm4a';
    return 'jpg';
  }
}
