import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import {
  Assignment,
  AssignmentContentType,
  AssignmentResource,
  AssignmentResourceType
} from '../../domain/model/HomeworkModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { RemoteAssignment } from './RemoteModels';

interface RemoteAssignmentResource {
  id: string;
  resourceType: string;
  originalName: string;
  contentType: string;
  sizeBytes: number;
  sortOrder: number;
  durationMs: number;
  downloadPath: string;
}

export interface RemoteVoiceAssignmentCreateResponse {
  assignment: RemoteAssignment;
  resources: RemoteAssignmentResource[];
}

interface MultipartPayload {
  boundary: string;
  body: ArrayBuffer;
}

// 与后端 AssignmentResourceService.classifyAttachment 的限制保持一致（VIDEO 由 200MB 收紧为 50MB）。
const MAX_ATTACHMENT_VIDEO_BYTES: number = 50 * 1024 * 1024;
const MAX_ATTACHMENT_AUDIO_BYTES: number = 30 * 1024 * 1024;
const MAX_ATTACHMENT_IMAGE_BYTES: number = 10 * 1024 * 1024;
// 与后端 VoiceMediaPolicy 保持一致：语音作业音频 20MB、情景图片单张 5MB。
const MAX_VOICE_AUDIO_BYTES: number = 20 * 1024 * 1024;
const MAX_VOICE_IMAGE_BYTES: number = 5 * 1024 * 1024;
// 下载的作业资料缓存上限：超过后按最旧优先清理，避免 cacheDir 只增不减。
const MAX_RESOURCE_CACHE_ENTRIES: number = 12;

interface VoiceAssignmentMetadata {
  id: string;
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  taskDate: string;
  assignmentType: string;
  subjectCode: string;
  contentType: string;
  status: string;
  sourceLabel: string;
  sourceExcerpt: string;
  expectedMinutes: number;
  startedAtEpochMs: number;
  finishedAtEpochMs: number;
  elapsedSeconds: number;
  reviewNote: string;
}

export class RemoteAssignmentResourceApi {
  static readonly instance: RemoteAssignmentResourceApi = new RemoteAssignmentResourceApi();
  private context: common.UIAbilityContext | null = null;
  private cache: Map<string, string> = new Map<string, string>();
  private cachePaths: Map<string, string> = new Map<string, string>();
  private cacheOrder: string[] = [];
  private pendingDownloads: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private tempSeq: number = 0;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async list(assignmentId: string): Promise<AssignmentResource[]> {
    if (!BackendSession.instance.isConnected()) return [];
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.resource.list',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/resources`,
      http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error('读取作业资料失败');
    let remote = JSON.parse(response.body) as RemoteAssignmentResource[];
    let result: AssignmentResource[] = [];
    for (let item of remote) result.push(this.toDomain(item));
    return result;
  }

  async createVoiceAssignment(assignment: Assignment, audioUri: string,
    imageUris: string[]): Promise<RemoteVoiceAssignmentCreateResponse> {
    if (this.context === null) throw new Error('语音作业服务尚未初始化');
    if (!BackendSession.instance.isConnected()) throw new Error('当前离线，联网后才能发布语音作业');
    if (audioUri.length === 0) throw new Error('请选择语音文件');
    if (imageUris.length === 0) throw new Error('请至少选择 1 张情景图片');
    await this.validateSourceSize(audioUri, MAX_VOICE_AUDIO_BYTES, '语音文件不能超过 20MB，请压缩后重试');
    for (let i = 0; i < imageUris.length; i++) {
      await this.validateSourceSize(imageUris[i], MAX_VOICE_IMAGE_BYTES, '情景图片不能超过 5MB，请压缩后重试');
    }

    let payload = await this.buildMultipartPayload(assignment, audioUri, imageUris);
    let client = http.createHttp();
    try {
      let path = `/api/v1/students/${encodeURIComponent(assignment.studentId)}/assignments/voice`;
      let headers = BackendHttpClient.instance.traceHeaders(
        path, http.RequestMethod.POST, 'assignment.voice.publish');
      headers['Authorization'] = `Bearer ${BackendSession.instance.getToken()}`;
      headers['Content-Type'] = `multipart/form-data; boundary=${payload.boundary}`;
      let response = await client.request(
        `${BackendSession.instance.getBaseUrl()}${path}`,
        {
          method: http.RequestMethod.POST,
          header: headers,
          extraData: payload.body,
          connectTimeout: 15000,
          readTimeout: 90000
        });
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        throw new Error('登录已失效，请重新连接家庭云端');
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`发布语音作业失败: ${response.responseCode}`);
      }
      let text = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return JSON.parse(text) as RemoteVoiceAssignmentCreateResponse;
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('发布语音作业失败')) throw error;
      throw new Error('语音作业上传失败，请检查网络后重试');
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  /** Upload an optional mixed-media resource to an existing ordinary assignment. */
  async uploadAttachment(assignmentId: string, sourceUri: string, resourceType: AssignmentResourceType): Promise<AssignmentResource> {
    if (this.context === null || !BackendSession.instance.isConnected()) {
      throw new Error('上传附件需要连接家庭云端');
    }
    let maxSize = resourceType === AssignmentResourceType.VIDEO ? MAX_ATTACHMENT_VIDEO_BYTES :
      (resourceType === AssignmentResourceType.AUDIO ? MAX_ATTACHMENT_AUDIO_BYTES : MAX_ATTACHMENT_IMAGE_BYTES);
    // 先校验源文件大小再组包：避免把大文件整个读进内存造成 OOM，也避免白做一次上传缓存。
    await this.validateSourceSize(sourceUri, maxSize, this.attachmentSizeError(resourceType, maxSize));
    let name = this.fileName(sourceUri, resourceType === AssignmentResourceType.VIDEO ? 'video.mp4' :
      (resourceType === AssignmentResourceType.AUDIO ? 'audio.mp3' : 'image.jpg'));
    let mime = resourceType === AssignmentResourceType.VIDEO ? 'video/mp4' :
      (resourceType === AssignmentResourceType.AUDIO ? this.audioContentType(sourceUri) : this.imageContentType(sourceUri));
    let boundary = '----xiaoban-resource-' + this.uniqueToken();
    let temp = this.context.cacheDir + '/upload-resource-' + this.uniqueToken() + '.bin';
    let writer = await this.openFile(temp,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      '无法创建上传缓存');
    let size = 0;
    try {
      size += await this.writeFilePart(writer.fd, boundary, 'file', sourceUri, name, mime);
      size += await this.writeText(writer.fd, '--' + boundary + '--\r\n', '附件上传封装失败');
    } finally {
      try { await fileIo.close(writer); } catch {}
    }
    // 源文件已提前校验；这里只防御 multipart 封装后的体积异常（头部开销极小）。
    if (size > maxSize + 64 * 1024) {
      try { await fileIo.unlink(temp); } catch {}
      throw new Error(this.attachmentSizeError(resourceType, maxSize));
    }
    let bytes = new ArrayBuffer(size);
    let reader = await this.openFile(temp, fileIo.OpenMode.READ_ONLY, '无法读取上传缓存');
    let position = 0;
    try {
      let chunk = new ArrayBuffer(64 * 1024);
      while (position < size) {
        let count = await this.readBuffer(reader.fd, chunk, '读取附件失败');
        if (count <= 0) break;
        new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), position);
        position += count;
      }
    } finally {
      try { await fileIo.close(reader); } catch {}
      try { await fileIo.unlink(temp); } catch {}
    }
    if (position !== size) throw new Error('附件读取不完整');
    let route = '/api/v1/assignments/' + encodeURIComponent(assignmentId) + '/resources';
    let client = http.createHttp();
    try {
      let headers = BackendHttpClient.instance.traceHeaders(route, http.RequestMethod.POST, 'assignment.resource.upload');
      headers['Authorization'] = 'Bearer ' + BackendSession.instance.getToken();
      headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary;
      let response: http.HttpResponse;
      try {
        response = await client.request(BackendSession.instance.getBaseUrl() + route, {
        method: http.RequestMethod.POST, header: headers, extraData: bytes,
          connectTimeout: 15000, readTimeout: 120000
        });
      } catch {
        throw new Error('附件上传请求失败，请检查网络后重试');
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error('附件上传失败：HTTP ' + response.responseCode);
      }
      let result: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return this.toDomain(JSON.parse(result) as RemoteAssignmentResource);
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  async removeAttachment(assignmentId: string, resourceId: string): Promise<void> {
    let path = '/api/v1/assignments/' + encodeURIComponent(assignmentId) +
      '/resources/' + encodeURIComponent(resourceId);
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.resource.delete', path, http.RequestMethod.DELETE);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error('删除附件失败');
    this.invalidate(resourceId);
  }

  invalidate(resourceId: string): void {
    this.cache.delete(resourceId);
    this.cachePaths.delete(resourceId);
    let remaining: string[] = [];
    for (let id of this.cacheOrder) {
      if (id !== resourceId) remaining.push(id);
    }
    this.cacheOrder = remaining;
  }

  private evictOverflowCache(): void {
    while (this.cacheOrder.length > MAX_RESOURCE_CACHE_ENTRIES) {
      let oldest = this.cacheOrder.shift();
      if (oldest === undefined) break;
      this.cache.delete(oldest);
      let path = this.cachePaths.get(oldest);
      this.cachePaths.delete(oldest);
      if (path !== undefined) {
        try { fileIo.unlinkSync(path); } catch {
          // 清理失败不影响本次下载结果；残留文件在下次驱逐时再试。
        }
      }
    }
  }

  async preload(resource: AssignmentResource): Promise<string> {
    return await this.download(resource);
  }

  async download(resource: AssignmentResource): Promise<string> {
    let cached = this.cache.get(resource.id);
    if (cached !== undefined && cached.length > 0) return cached;

    let pending = this.pendingDownloads.get(resource.id);
    if (pending !== undefined) return await pending;

    let task = this.downloadUncached(resource);
    this.pendingDownloads.set(resource.id, task);
    try {
      return await task;
    } finally {
      this.pendingDownloads.delete(resource.id);
    }
  }

  private async downloadUncached(resource: AssignmentResource): Promise<string> {
    if (this.context === null || !BackendSession.instance.isConnected()) return '';

    let client = http.createHttp();
    try {
      let path = resource.downloadPath.length > 0 ?
        resource.downloadPath : `/api/v1/assignment-resources/${encodeURIComponent(resource.id)}`;
      let headers = BackendHttpClient.instance.traceHeaders(
        path, http.RequestMethod.GET, 'assignment.resource.download');
      headers['Authorization'] = `Bearer ${BackendSession.instance.getToken()}`;
      let response = await client.request(
        `${BackendSession.instance.getBaseUrl()}${path}`,
        {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: 10000,
          readTimeout: 60000,
          maxLimit: 205 * 1024 * 1024,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        });
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        return '';
      }
      if (response.responseCode !== http.ResponseCode.OK) return '';

      let data = response.result as ArrayBuffer;
      if (data.byteLength === 0) return '';
      let cachePath = `${this.context.cacheDir}/assignment-resource-${resource.id}.${this.extension(resource)}`;
      let file = await fileIo.open(cachePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, data);
      } finally {
        try { await fileIo.close(file); } catch {}
      }
      let uri = fileUri.getUriFromPath(cachePath);
      this.invalidate(resource.id);
      this.cache.set(resource.id, uri);
      this.cachePaths.set(resource.id, cachePath);
      this.cacheOrder.push(resource.id);
      this.evictOverflowCache();
      return uri;
    } catch {
      return '';
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  private toDomain(item: RemoteAssignmentResource): AssignmentResource {
    return {
      id: item.id,
      resourceType: item.resourceType === AssignmentResourceType.AUDIO ? AssignmentResourceType.AUDIO :
        (item.resourceType === AssignmentResourceType.VIDEO ? AssignmentResourceType.VIDEO : AssignmentResourceType.IMAGE),
      originalName: item.originalName,
      contentType: item.contentType,
      sizeBytes: item.sizeBytes,
      sortOrder: item.sortOrder,
      durationMs: item.durationMs,
      downloadPath: item.downloadPath
    };
  }

  private metadata(assignment: Assignment): VoiceAssignmentMetadata {
    return {
      id: assignment.id,
      subject: assignment.subject,
      title: assignment.title,
      instruction: assignment.instruction,
      textbookRef: assignment.textbookRef,
      taskDate: assignment.taskDate,
      assignmentType: assignment.assignmentType,
      subjectCode: assignment.subjectCode,
      contentType: AssignmentContentType.AUDIO_IMAGE,
      status: assignment.status,
      sourceLabel: '',
      sourceExcerpt: '',
      expectedMinutes: assignment.expectedMinutes,
      startedAtEpochMs: assignment.startedAtEpochMs,
      finishedAtEpochMs: assignment.finishedAtEpochMs,
      elapsedSeconds: assignment.elapsedSeconds,
      reviewNote: assignment.reviewNote
    };
  }

  private async buildMultipartPayload(assignment: Assignment, audioUri: string,
    imageUris: string[]): Promise<MultipartPayload> {
    if (this.context === null) throw new Error('语音作业服务尚未初始化');
    let boundary = `----xiaoban-voice-${this.uniqueToken()}`;
    let multipartPath = `${this.context.cacheDir}/voice-assignment-${this.uniqueToken()}.bin`;

    try {
      let writer = await this.openFile(
        multipartPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
        '无法创建语音作业上传缓存');
      let totalBytes = 0;
      try {
        let metadataText = JSON.stringify(this.metadata(assignment));
        let metadataHeader = `--${boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n` +
          'Content-Type: application/json; charset=UTF-8\r\n\r\n';
        totalBytes += await this.writeText(writer.fd, metadataHeader, '无法写入语音作业元数据头');
        totalBytes += await this.writeText(writer.fd, metadataText, '无法写入语音作业元数据');
        totalBytes += await this.writeText(writer.fd, '\r\n', '无法结束语音作业元数据');

        totalBytes += await this.writeFilePart(
          writer.fd, boundary, 'audio', audioUri, this.fileName(audioUri, 'voice.mp3'),
          this.audioContentType(audioUri));
        for (let i = 0; i < imageUris.length; i++) {
          totalBytes += await this.writeFilePart(
            writer.fd, boundary, 'images', imageUris[i],
            this.fileName(imageUris[i], `scene-${i + 1}.jpg`), this.imageContentType(imageUris[i]));
        }
        totalBytes += await this.writeText(
          writer.fd, `--${boundary}--\r\n`, '无法结束语音作业上传请求');
      } finally {
        try { await fileIo.close(writer); } catch {}
      }

      let body = new ArrayBuffer(totalBytes);
      let target = new Uint8Array(body);
      let reader = await this.openFile(
        multipartPath, fileIo.OpenMode.READ_ONLY, '无法读取语音作业上传缓存');
      let offset = 0;
      try {
        let chunk = new ArrayBuffer(64 * 1024);
        while (offset < totalBytes) {
          let readLength = await this.readBuffer(
            reader.fd, chunk, '读取语音作业上传缓存失败');
          if (readLength <= 0) break;
          target.set(new Uint8Array(chunk, 0, readLength), offset);
          offset += readLength;
        }
      } finally {
        try { await fileIo.close(reader); } catch {}
      }
      if (offset !== totalBytes) throw new Error('语音作业上传请求读取不完整');
      return { boundary: boundary, body: body };
    } finally {
      try { await fileIo.unlink(multipartPath); } catch {}
    }
  }

  private async writeFilePart(fd: number, boundary: string, fieldName: string, uri: string,
    fileName: string, contentType: string): Promise<number> {
    let total = 0;
    let header = `--${boundary}\r\nContent-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n` +
      `Content-Type: ${contentType}\r\n\r\n`;
    total += await this.writeText(fd, header, '无法写入媒体文件上传头');
    let source = await this.openFile(uri, fileIo.OpenMode.READ_ONLY, '无法读取待上传媒体文件');
    try {
      let chunk = new ArrayBuffer(64 * 1024);
      while (true) {
        let readLength = await this.readBuffer(source.fd, chunk, '读取待上传媒体文件失败');
        if (readLength <= 0) break;
        let written = await this.writeBuffer(
          fd, chunk, readLength, '写入媒体文件上传内容失败');
        if (written !== readLength) throw new Error('媒体文件写入上传请求失败');
        total += written;
      }
    } finally {
      try { await fileIo.close(source); } catch {}
    }
    total += await this.writeText(fd, '\r\n', '无法结束媒体文件上传内容');
    return total;
  }

  private async openFile(path: string, mode: number, errorMessage: string): Promise<fileIo.File> {
    try {
      return await fileIo.open(path, mode);
    } catch {
      throw new Error(errorMessage);
    }
  }

  /** 临时文件名/边界令牌：毫秒时间戳 + 自增序号，杜绝同毫秒并发时互相截断。 */
  private uniqueToken(): string {
    this.tempSeq++;
    return `${Date.now()}-${this.tempSeq}`;
  }

  private async validateSourceSize(uri: string, maxBytes: number, errorMessage: string): Promise<void> {
    let source = await this.openFile(uri, fileIo.OpenMode.READ_ONLY, '无法读取待上传的文件');
    let size = 0;
    try {
      size = fileIo.statSync(source.fd).size;
    } catch {
      // 取不到大小就让服务端兜底判定，不在客户端把流程掐死。
      size = 0;
    }
    try { await fileIo.close(source); } catch {}
    if (size > maxBytes) throw new Error(errorMessage);
  }

  private attachmentSizeError(resourceType: AssignmentResourceType, maxBytes: number): string {
    let label = resourceType === AssignmentResourceType.VIDEO ? '视频' :
      (resourceType === AssignmentResourceType.AUDIO ? '语音' : '图片');
    let mb = Math.round(maxBytes / (1024 * 1024));
    return `${label}附件不能超过 ${mb}MB`;
  }

  private async writeText(fd: number, value: string, errorMessage: string): Promise<number> {
    try {
      return await fileIo.write(fd, value);
    } catch {
      throw new Error(errorMessage);
    }
  }

  private async readBuffer(fd: number, buffer: ArrayBuffer, errorMessage: string): Promise<number> {
    try {
      return await fileIo.read(fd, buffer);
    } catch {
      throw new Error(errorMessage);
    }
  }

  private async writeBuffer(fd: number, buffer: ArrayBuffer, length: number,
    errorMessage: string): Promise<number> {
    try {
      return await fileIo.write(fd, buffer, { length: length });
    } catch {
      throw new Error(errorMessage);
    }
  }

  private fileName(uri: string, fallback: string): string {
    let normalized = uri;
    let query = normalized.indexOf('?');
    if (query >= 0) normalized = normalized.substring(0, query);
    let slash = normalized.lastIndexOf('/');
    let name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    if (name.length === 0) return fallback;
    try {
      name = decodeURIComponent(name);
    } catch {}
    return name.indexOf('.') > 0 ? name : fallback;
  }

  private lowerUri(uri: string): string {
    let value = uri.toLowerCase();
    let query = value.indexOf('?');
    return query >= 0 ? value.substring(0, query) : value;
  }

  private audioContentType(uri: string): string {
    let value = this.lowerUri(uri);
    if (value.endsWith('.m4a')) return 'audio/mp4';
    if (value.endsWith('.wav')) return 'audio/wav';
    return 'audio/mpeg';
  }

  private imageContentType(uri: string): string {
    let value = this.lowerUri(uri);
    if (value.endsWith('.png')) return 'image/png';
    if (value.endsWith('.webp')) return 'image/webp';
    if (value.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  private extension(resource: AssignmentResource): string {
    let type = resource.contentType.toLowerCase();
    if (type.indexOf('png') >= 0) return 'png';
    if (type.indexOf('webp') >= 0) return 'webp';
    if (type.indexOf('heic') >= 0) return 'heic';
    if (type.indexOf('mpeg') >= 0) return 'mp3';
    if (resource.resourceType === AssignmentResourceType.VIDEO) return 'mp4';
    if (type.indexOf('mp4') >= 0 || type.indexOf('m4a') >= 0) return 'm4a';
    if (type.indexOf('wav') >= 0) return 'wav';
    return resource.resourceType === AssignmentResourceType.AUDIO ? 'mp3' : 'jpg';
  }
}
