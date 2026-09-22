import {
  VoiceMaterialDirectoryPicker,
  VoiceMaterialLocalFile,
  VoiceMaterialLocalPackage,
  VoiceMaterialLocalResourceType
} from '../../../application/assignment/VoiceMaterialDirectoryPicker';
import {
  RemoteVoiceMaterialApi,
  RemoteVoiceMaterialBatch,
  RemoteVoiceMaterialPackage
} from '../../../application/remote/RemoteVoiceMaterialApi';
import { RemoteAssignmentMapper } from '../../../application/remote/RemoteModels';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, StudentProfile } from '../../../domain/model/HomeworkModels';

export interface VoiceMaterialLocalValidation {
  valid: boolean;
  audioCount: number;
  imageCount: number;
  message: string;
}

export class ParentVoiceMaterialViewModel {
  private readonly repository: DefaultAssignmentRepository;

  constructor(repository: DefaultAssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  async selectPackages(defaultSubjectCode: string,
    expectedMinutes: number): Promise<VoiceMaterialLocalPackage[]> {
    return await VoiceMaterialDirectoryPicker.instance.selectPackages(
      defaultSubjectCode, expectedMinutes);
  }

  validate(item: VoiceMaterialLocalPackage): VoiceMaterialLocalValidation {
    let audioCount = 0;
    let imageCount = 0;
    for (let file of item.files) {
      if (file.resourceType === VoiceMaterialLocalResourceType.AUDIO) audioCount++;
      else if (file.resourceType === VoiceMaterialLocalResourceType.IMAGE) imageCount++;
    }
    if (audioCount === 0) return {
      valid: false, audioCount: audioCount, imageCount: imageCount, message: '缺少语音文件'
    };
    if (audioCount > 1) return {
      valid: false, audioCount: audioCount, imageCount: imageCount, message: '只能有 1 个语音文件'
    };
    if (imageCount === 0) return {
      valid: false, audioCount: audioCount, imageCount: imageCount, message: '至少需要 1 张图片'
    };
    return {
      valid: true, audioCount: audioCount, imageCount: imageCount, message: '可以导入'
    };
  }

  async upload(packages: VoiceMaterialLocalPackage[]): Promise<RemoteVoiceMaterialBatch> {
    if (packages.length === 0) throw new Error('请先添加语音素材目录');
    for (let item of packages) {
      if (!this.validate(item).valid) {
        throw new Error(`${item.directoryName}：${this.validate(item).message}`);
      }
    }

    let batch = await RemoteVoiceMaterialApi.instance.createBatch(this.student().id);
    for (let item of packages) {
      let remotePackage = await RemoteVoiceMaterialApi.instance.registerPackage(batch.id, {
        directoryName: item.directoryName,
        subjectCode: item.subjectCode,
        title: '',
        expectedMinutes: item.expectedMinutes,
        dueAtEpochMs: 0,
        assignmentType: 'EXTRA'
      });
      await this.uploadPackageFiles(remotePackage.id, item.files);
    }
    return await RemoteVoiceMaterialApi.instance.completeBatch(batch.id);
  }

  async list(): Promise<RemoteVoiceMaterialPackage[]> {
    return await RemoteVoiceMaterialApi.instance.list(this.student().id);
  }

  async createAssignment(item: RemoteVoiceMaterialPackage): Promise<Assignment | null> {
    let result = await RemoteVoiceMaterialApi.instance.createAssignment(item.id);
    if (result.assignment === null) return null;
    let existing = this.repository.getCached(result.assignment.id);
    let mapped = RemoteAssignmentMapper.toLocal(result.assignment, existing);
    mapped.resourceLabels = item.files.map((file) => file.relativeName);
    this.repository.applyAuthoritative(mapped);
    return mapped;
  }

  private async uploadPackageFiles(packageId: string,
    files: VoiceMaterialLocalFile[]): Promise<void> {
    let sorted = files.slice();
    sorted.sort((left: VoiceMaterialLocalFile, right: VoiceMaterialLocalFile) => {
      if (left.resourceType !== right.resourceType) {
        return left.resourceType === VoiceMaterialLocalResourceType.AUDIO ? -1 : 1;
      }
      return left.name.localeCompare(right.name);
    });

    let imageOrder = 1;
    for (let file of sorted) {
      let order = file.resourceType === VoiceMaterialLocalResourceType.AUDIO ? 0 : imageOrder++;
      await RemoteVoiceMaterialApi.instance.uploadFile(
        packageId, file.resourceType, file.name, order, file.uri);
    }
  }
}
