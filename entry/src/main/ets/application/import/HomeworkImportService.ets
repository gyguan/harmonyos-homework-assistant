import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkStore } from '../../data/HomeworkStore';
import { HomeworkImageImportResult, HomeworkImportPipelineResult } from '../../domain/model/ImportModels';
import { HomeworkImportSourceKind, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';
import { HomeworkImportPipeline } from './HomeworkImportPipeline';

export class HomeworkImportService {
  static readonly instance: HomeworkImportService = new HomeworkImportService();

  private pipeline: HomeworkImportPipeline | null = null;

  private constructor() {}

  configure(extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser): void {
    this.pipeline = new HomeworkImportPipeline(extractor, parser);
  }

  async parseText(text: string): Promise<number> {
    if (this.pipeline === null) {
      throw new Error('作业导入能力尚未初始化');
    }
    let normalized = text.trim();
    if (normalized.length === 0) {
      return 0;
    }

    let studentId = HomeworkStore.instance.getActiveStudentId();
    let rawImport: RawHomeworkImport = {
      id: `text-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: '家长录入文字',
      resourceUri: '',
      rawText: normalized
    };
    let output: HomeworkImportPipelineResult = await this.pipeline.run(rawImport);
    if (output.candidates.length === 0) {
      return 0;
    }

    HomeworkStore.instance.replaceRawImport({
      id: rawImport.id,
      studentId: studentId,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: output.extracted.text
    });
    HomeworkStore.instance.replaceCandidates(output.candidates);
    return output.candidates.length;
  }

  async reparseCurrentImport(): Promise<number> {
    if (this.pipeline === null) {
      return 0;
    }
    let current = HomeworkStore.instance.getRawImport();
    let output = await this.pipeline.run(current);
    if (output.candidates.length === 0) {
      return 0;
    }
    HomeworkStore.instance.replaceRawImport({
      id: current.id,
      studentId: current.studentId,
      sourceKind: current.sourceKind,
      sourceLabel: current.sourceLabel,
      resourceUri: current.resourceUri,
      rawText: output.extracted.text
    });
    HomeworkStore.instance.replaceCandidates(output.candidates);
    return output.candidates.length;
  }

  async selectImageAndParse(): Promise<HomeworkImageImportResult> {
    if (this.pipeline === null) {
      throw new Error('作业导入能力尚未初始化');
    }

    let photoUris: string[] = [];
    try {
      let picker = new photoAccessHelper.PhotoViewPicker();
      let selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      photoUris = selection.photoUris.slice();
    } catch {
      throw new Error('无法打开相册或读取所选图片');
    }

    if (photoUris.length === 0) {
      return {
        selected: false,
        candidateCount: 0,
        recognizedText: ''
      };
    }

    let studentId = HomeworkStore.instance.getActiveStudentId();
    let rawImport: RawHomeworkImport = {
      id: `image-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: '相册作业截图',
      resourceUri: photoUris[0],
      rawText: ''
    };

    let output: HomeworkImportPipelineResult = await this.pipeline.run(rawImport);
    HomeworkStore.instance.replaceRawImport({
      id: rawImport.id,
      studentId: studentId,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: output.extracted.text
    });
    if (output.candidates.length > 0) {
      HomeworkStore.instance.replaceCandidates(output.candidates);
    }

    return {
      selected: true,
      candidateCount: output.candidates.length,
      recognizedText: output.extracted.text
    };
  }
}
