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

interface VoiceAssignmentMetadata {
  id: string;
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  assignmentType: string;
  subjectCode: string;
  contentType: string;
  dueAtEpochMs: number;
  dueTimezone: string;
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
  private pendingDownloads: Map<string, Promise<string>> = new Map<string, Promise<string>>();

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
      let cachePath = `${this.context.cacheDir}/assignment-resource-${resource.id}.${this.extension(resource)}`;
      let file = await fileIo.open(cachePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, data);
      } finally {
        try { await fileIo.close(file); } catch {}
      }
      let uri = fileUri.getUriFromPath(cachePath);
      this.cache.set(resource.id, uri);
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
      resourceType: item.resourceType === AssignmentResourceType.AUDIO ?
        AssignmentResourceType.AUDIO : AssignmentResourceType.IMAGE,
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
      dueText: assignment.dueText,
      assignmentType: assignment.assignmentType,
      subjectCode: assignment.subjectCode,
      contentType: AssignmentContentType.AUDIO_IMAGE,
      dueAtEpochMs: assignment.dueAtEpochMs,
      dueTimezone: assignment.dueTimezone,
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
    let boundary = `----xiaoban-voice-${Date.now()}`;
    let multipartPath = `${this.context.cacheDir}/voice-assignment-${Date.now()}.bin`;

    try {
      let writer = await fileIo.open(multipartPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      let totalBytes = 0;
      try {
        let metadataText = JSON.stringify(this.metadata(assignment));
        let metadataHeader = `--${boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n` +
          'Content-Type: application/json; charset=UTF-8\r\n\r\n';
        totalBytes += await fileIo.write(writer.fd, metadataHeader);
        totalBytes += await fileIo.write(writer.fd, metadataText);
        totalBytes += await fileIo.write(writer.fd, '\r\n');

        totalBytes += await this.writeFilePart(
          writer.fd, boundary, 'audio', audioUri, this.fileName(audioUri, 'voice.mp3'),
          this.audioContentType(audioUri));
        for (let i = 0; i < imageUris.length; i++) {
          totalBytes += await this.writeFilePart(
            writer.fd, boundary, 'images', imageUris[i],
            this.fileName(imageUris[i], `scene-${i + 1}.jpg`), this.imageContentType(imageUris[i]));
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
    total += await fileIo.write(fd, header);
    let source = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    try {
      let chunk = new ArrayBuffer(64 * 1024);
      while (true) {
        let readLength = await fileIo.read(source.fd, chunk);
        if (readLength <= 0) break;
        let written = await fileIo.write(fd, chunk, { length: readLength });
        if (written !== readLength) throw new Error('媒体文件写入上传请求失败');
        total += written;
      }
    } finally {
      try { await fileIo.close(source); } catch {}
    }
    total += await fileIo.write(fd, '\r\n');
    return total;
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
    if (type.indexOf('mp4') >= 0 || type.indexOf('m4a') >= 0) return 'm4a';
    if (type.indexOf('wav') >= 0) return 'wav';
    return resource.resourceType === AssignmentResourceType.AUDIO ? 'mp3' : 'jpg';
  }
}
