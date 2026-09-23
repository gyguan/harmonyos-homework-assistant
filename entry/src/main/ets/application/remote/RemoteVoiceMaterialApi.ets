import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { VoiceMaterialLocalResourceType } from '../assignment/VoiceMaterialDirectoryPicker';
import { RemoteAssignment } from './RemoteModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

export interface RemoteVoiceMaterialBatch {
  id: string;
  studentId: string;
  directoryCount: number;
  readyCount: number;
  invalidCount: number;
}

export interface RemoteVoiceMaterialFile {
  id: string;
  assetId: string;
  resourceType: string;
  relativeName: string;
  sortOrder: number;
}

export interface RemoteVoiceMaterialPackage {
  id: string;
  batchId: string;
  studentId: string;
  directoryName: string;
  subjectCode: string;
  title: string;
  expectedMinutes: number;
  dueAtEpochMs: number;
  assignmentType: string;
  status: string;
  errorMessage: string;
  consumedAssignmentId: string;
  hasCreatedBefore: boolean;
  hasActiveAssignment: boolean;
  files: RemoteVoiceMaterialFile[];
}

export interface RemoteVoiceMaterialRegisterPackageRequest {
  directoryName: string;
  subjectCode: string;
  title: string;
  expectedMinutes: number;
  dueAtEpochMs: number;
  assignmentType: string;
}

export interface RemoteVoiceMaterialCreateAssignmentRequest {
  studentId: string;
  expectedMinutes: number;
  dueAtEpochMs: number;
  dueText: string;
  title: string;
  requestId: string;
}

export interface RemoteVoiceFolderItem {
  packageId: string;
  directoryName: string;
  folderStatus: string;
  studentId: string;
  studentName: string;
  subjectCode: string;
  expectedMinutes: number;
  audioCount: number;
  imageCount: number;
  usageCount: number;
  activeTaskCount: number;
  lastUsedAtEpochMs: number;
  importedAtEpochMs: number;
  errorMessage: string;
}

export interface RemoteVoiceFolderPage {
  items: RemoteVoiceFolderItem[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface RemoteVoiceMaterialCreateAssignmentResponse {
  created: boolean;
  assignmentId: string;
  assignment: RemoteAssignment | null;
}

export interface RemoteVoiceMaterialAutoCreateResponse {
  created: boolean;
  businessDate: string;
  packageId: string;
  assignmentId: string;
  assignment: RemoteAssignment | null;
}

interface MultipartPayload {
  boundary: string;
  body: ArrayBuffer;
}

export class RemoteVoiceMaterialApi {
  static readonly instance: RemoteVoiceMaterialApi = new RemoteVoiceMaterialApi();
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async createBatch(studentId: string): Promise<RemoteVoiceMaterialBatch> {
    this.requireConnected();
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.batch.create',
      `/api/v1/students/${encodeURIComponent(studentId)}/voice-material-batches`,
      http.RequestMethod.POST);
    this.requireSuccess(response.statusCode, '创建语音素材批次失败');
    return JSON.parse(response.body) as RemoteVoiceMaterialBatch;
  }

  async registerPackage(batchId: string,
    input: RemoteVoiceMaterialRegisterPackageRequest): Promise<RemoteVoiceMaterialPackage> {
    this.requireConnected();
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.package.create',
      `/api/v1/voice-material-batches/${encodeURIComponent(batchId)}/packages`,
      http.RequestMethod.POST,
      input);
    this.requireSuccess(response.statusCode, '创建语音素材目录失败');
    return JSON.parse(response.body) as RemoteVoiceMaterialPackage;
  }

  async uploadFile(packageId: string, resourceType: VoiceMaterialLocalResourceType,
    relativeName: string, sortOrder: number, uri: string): Promise<RemoteVoiceMaterialFile> {
    if (this.context === null) throw new Error('语音素材上传服务尚未初始化');
    this.requireConnected();

    let payload = await this.buildMultipartPayload(uri, relativeName);
    let query = `resourceType=${encodeURIComponent(resourceType)}&relativeName=${encodeURIComponent(relativeName)}&sortOrder=${sortOrder}`;
    let path = `/api/v1/voice-material-packages/${encodeURIComponent(packageId)}/files?${query}`;
    let headers = BackendHttpClient.instance.traceHeaders(
      path, http.RequestMethod.POST, 'voice.material.file.upload');
    headers['Authorization'] = `Bearer ${BackendSession.instance.getToken()}`;
    headers['Content-Type'] = `multipart/form-data; boundary=${payload.boundary}`;

    let client = http.createHttp();
    try {
      let response = await this.requestUpload(client, path, headers, payload.body);
      if (response.responseCode === 401) {
        BackendSession.instance.disconnect();
        throw new Error('登录已失效，请重新连接家庭云端');
      }
      this.requireSuccess(response.responseCode, '上传语音素材文件失败');
      let text = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return JSON.parse(text) as RemoteVoiceMaterialFile;
    } finally {
      try { client.destroy(); } catch {}
    }
  }

  async completeBatch(batchId: string): Promise<RemoteVoiceMaterialBatch> {
    this.requireConnected();
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.batch.complete',
      `/api/v1/voice-material-batches/${encodeURIComponent(batchId)}/complete`,
      http.RequestMethod.POST);
    this.requireSuccess(response.statusCode, '完成语音素材导入失败');
    return JSON.parse(response.body) as RemoteVoiceMaterialBatch;
  }

  async list(studentId: string): Promise<RemoteVoiceMaterialPackage[]> {
    if (!BackendSession.instance.isConnected()) return [];
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.list',
      `/api/v1/students/${encodeURIComponent(studentId)}/voice-material-packages`,
      http.RequestMethod.GET);
    this.requireSuccess(response.statusCode, '读取语音素材库失败');
    return JSON.parse(response.body) as RemoteVoiceMaterialPackage[];
  }

  async queryFolders(studentId: string, keyword: string = '', usage: string = 'ALL',
    page: number = 0, size: number = 20): Promise<RemoteVoiceFolderPage> {
    if (!BackendSession.instance.isConnected()) {
      return { items: [], page: 0, size: size, totalElements: 0, totalPages: 0 };
    }
    let params: string[] = [
      `studentId=${encodeURIComponent(studentId)}`,
      `usage=${encodeURIComponent(usage)}`,
      `page=${Math.max(0, page)}`,
      `size=${Math.max(1, Math.min(100, size))}`,
      'sort=importedAt,desc'
    ];
    if (keyword.trim().length > 0) {
      params.push(`keyword=${encodeURIComponent(keyword.trim())}`);
    }
    let path = `/api/v1/voice-material-folders?${params.join('&')}`;
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.folder.query', path, http.RequestMethod.GET);
    this.requireSuccess(response.statusCode, '读取服务器语音文件夹失败');
    return JSON.parse(response.body) as RemoteVoiceFolderPage;
  }

  async createAssignment(packageId: string, input: RemoteVoiceMaterialCreateAssignmentRequest):
    Promise<RemoteVoiceMaterialCreateAssignmentResponse> {
    this.requireConnected();
    let response = await BackendHttpClient.instance.requestFor(
      'voice.material.assignment.create',
      `/api/v1/voice-material-packages/${encodeURIComponent(packageId)}/create-assignment`,
      http.RequestMethod.POST, input);
    this.requireSuccess(response.statusCode, '从语音素材创建任务失败');
    return JSON.parse(response.body) as RemoteVoiceMaterialCreateAssignmentResponse;
  }

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

  private async buildMultipartPayload(uri: string, fileName: string): Promise<MultipartPayload> {
    if (this.context === null) throw new Error('语音素材上传服务尚未初始化');
    let boundary = `----xiaoban-voice-material-${Date.now()}`;
    let multipartPath = `${this.context.cacheDir}/voice-material-${Date.now()}.bin`;
    try {
      let writer = await this.openFile(
        multipartPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
        '无法创建语音素材上传缓存');
      let totalBytes = 0;
      try {
        let header =
          `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${this.safeFileName(fileName)}"\r\n` +
          `Content-Type: ${this.contentType(fileName)}\r\n\r\n`;
        totalBytes += await this.writeText(
          writer.fd, header, '无法写入语音素材上传请求头');

        let source = await this.openFile(uri, fileIo.OpenMode.READ_ONLY, '无法读取语音素材文件');
        try {
          let chunk = new ArrayBuffer(64 * 1024);
          while (true) {
            let readLength = await this.readBuffer(
              source.fd, chunk, '读取语音素材文件失败');
            if (readLength <= 0) break;
            let written = await this.writeBuffer(
              writer.fd, chunk, readLength, '写入语音素材上传缓存失败');
            if (written !== readLength) throw new Error('语音素材文件写入上传缓存失败');
            totalBytes += written;
          }
        } finally {
          try { await fileIo.close(source); } catch {}
        }

        totalBytes += await this.writeText(
          writer.fd, '\r\n', '无法结束语音素材文件内容');
        totalBytes += await this.writeText(
          writer.fd, `--${boundary}--\r\n`, '无法结束语音素材上传请求');
      } finally {
        try { await fileIo.close(writer); } catch {}
      }

      let body = new ArrayBuffer(totalBytes);
      let target = new Uint8Array(body);
      let reader = await this.openFile(
        multipartPath, fileIo.OpenMode.READ_ONLY, '无法读取语音素材上传缓存');
      let offset = 0;
      try {
        let chunk = new ArrayBuffer(64 * 1024);
        while (offset < totalBytes) {
          let readLength = await this.readBuffer(
            reader.fd, chunk, '读取语音素材上传缓存失败');
          if (readLength <= 0) break;
          target.set(new Uint8Array(chunk, 0, readLength), offset);
          offset += readLength;
        }
      } finally {
        try { await fileIo.close(reader); } catch {}
      }
      if (offset !== totalBytes) throw new Error('语音素材上传缓存读取不完整');
      return { boundary: boundary, body: body };
    } finally {
      try { await fileIo.unlink(multipartPath); } catch {}
    }
  }

  private async requestUpload(client: http.HttpRequest, path: string,
    headers: Record<string, string>, body: ArrayBuffer): Promise<http.HttpResponse> {
    try {
      let options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: 15000,
        readTimeout: 90000
      };
      return await client.request(BackendSession.instance.getBaseUrl() + path, options);
    } catch {
      throw new Error('上传语音素材时网络请求失败');
    }
  }

  private async openFile(path: string, mode: number, errorMessage: string): Promise<fileIo.File> {
    try {
      return await fileIo.open(path, mode);
    } catch {
      throw new Error(errorMessage);
    }
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

  private safeFileName(fileName: string): string {
    let value = fileName.replace(/["\\\r\n]/g, '_').trim();
    return value.length === 0 ? 'material.bin' : value;
  }

  private contentType(fileName: string): string {
    let lower = fileName.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  private requireConnected(): void {
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，连接家庭云端后才能管理语音素材');
    }
  }

  private requireSuccess(statusCode: number, message: string): void {
    if (statusCode < 200 || statusCode >= 300) throw new Error(`${message}: ${statusCode}`);
  }
}
