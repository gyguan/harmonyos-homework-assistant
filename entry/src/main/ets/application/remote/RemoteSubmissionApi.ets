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
  private static readonly CACHE_PREFIX: string = 'submission-resource-';
  private context: common.UIAbilityContext | null = null;
  /** resourceId → 本地文件 URI（原图） */
  private resourceCache: Map<string, string> = new Map<string, string>();
  /** `${resourceId}#${width}` → 本地文件 URI（缩略图） */
  private thumbnailCache: Map<string, string> = new Map<string, string>();
  private pending: Map<string, Promise<string>> = new Map<string, Promise<string>>();

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
    this.registerDiskCache();
  }

  /**
   * 冷启动时把 cacheDir 里已经下过的图片重新登记进内存索引。
   *
   * 这些文件本来就一直在，但以前只在内存 Map 里记着，App 一重启就全丢了，
   * 于是每张 2~3MB 的原图都会被重新下一遍（3Mbps 出口，一张要 8 秒）。
   */
  private registerDiskCache(): void {
    if (this.context === null) return;
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(this.context.cacheDir);
    } catch {
      return;
    }
    for (let name of names) {
      if (name.indexOf(RemoteSubmissionApi.CACHE_PREFIX) !== 0) continue;
      let rest = name.substring(RemoteSubmissionApi.CACHE_PREFIX.length);
      let dot = rest.lastIndexOf('.');
      if (dot <= 0) continue;
      let base = rest.substring(0, dot);
      let uri = fileUri.getUriFromPath(`${this.context.cacheDir}/${name}`);
      let thumbAt = base.lastIndexOf('-w');
      if (thumbAt > 0) {
        let width = Number.parseInt(base.substring(thumbAt + 2), 10);
        if (!Number.isNaN(width) && width > 0) {
          this.thumbnailCache.set(`${base.substring(0, thumbAt)}#${width}`, uri);
          continue;
        }
      }
      this.resourceCache.set(base, uri);
    }
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

  cachedThumbnailUri(resourceId: string, width: number): string {
    let cached = this.thumbnailCache.get(`${resourceId}#${width}`);
    return cached === undefined ? '' : cached;
  }

  async downloadResource(resource: RemoteSubmissionResource): Promise<string> {
    return await this.downloadInternal(resource, 0);
  }

  async downloadPhoto(resource: RemoteSubmissionResource): Promise<string> {
    return await this.downloadInternal(resource, 0);
  }

  /**
   * 列表/缩略图用的小图。
   *
   * 原图一张 2~3MB、服务器出口约 3Mbps，直接拿原图渲染 86vp 的小格子要等 8 秒；
   * 服务端支持 `?w=` 现场生成缩略图（约 20KB），首屏能瞬间出图。
   */
  async downloadThumbnail(resource: RemoteSubmissionResource, width: number = 320): Promise<string> {
    return await this.downloadInternal(resource, Math.max(1, Math.floor(width)));
  }

  private async downloadInternal(resource: RemoteSubmissionResource, width: number): Promise<string> {
    let thumb = width > 0;
    let key = thumb ? `${resource.id}#${width}` : resource.id;
    let cached = thumb ? this.thumbnailCache.get(key) : this.resourceCache.get(key);
    if (cached !== undefined && cached.length > 0) return cached;
    let inFlight = this.pending.get(key);
    if (inFlight !== undefined) return await inFlight;

    let task = this.downloadUncached(resource, width);
    this.pending.set(key, task);
    try {
      return await task;
    } finally {
      this.pending.delete(key);
    }
  }

  private async downloadUncached(resource: RemoteSubmissionResource, width: number): Promise<string> {
    if (this.context === null || !BackendSession.instance.isConnected()) return '';
    let thumb = width > 0;

    let client = http.createHttp();
    try {
      let basePath = resource.downloadPath.length > 0 ?
        resource.downloadPath : `/api/v1/submission-resources/${encodeURIComponent(resource.id)}`;
      let path = thumb ? `${basePath}?w=${width}` : basePath;
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
      // 缩略图服务端统一重编码为 JPEG；原图沿用资源本身的扩展名。
      let extension = thumb ? 'jpg' : this.extension(resource);
      let suffix = thumb ? `-w${width}` : '';
      let cachePath = `${this.context.cacheDir}/${RemoteSubmissionApi.CACHE_PREFIX}${resource.id}${suffix}.${extension}`;
      let file = await fileIo.open(cachePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, data);
      } finally {
        try { await fileIo.close(file); } catch {}
      }
      let uri = fileUri.getUriFromPath(cachePath);
      if (thumb) {
        this.thumbnailCache.set(`${resource.id}#${width}`, uri);
      } else {
        this.resourceCache.set(resource.id, uri);
      }
      return uri;
    } catch {
      return '';
    } finally {
      try { client.destroy(); } catch {}
    }
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
