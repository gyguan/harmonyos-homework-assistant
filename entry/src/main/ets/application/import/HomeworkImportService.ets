import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkOrganizerRemoteApi } from '../remote/HomeworkOrganizerRemoteApi';
import { DefaultHomeworkImportDraftRepository } from '../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  ExtractedHomeworkText,
  HomeworkImageImportResult,
  HomeworkImportPipelineResult,
  HomeworkOrganizerMode,
  HomeworkTextImportResult
} from '../../domain/model/ImportModels';
import { CandidateAssignment, HomeworkImportSourceKind, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';
import { HomeworkImportPipeline } from './HomeworkImportPipeline';

export class HomeworkImportService {
  static readonly instance: HomeworkImportService = new HomeworkImportService();

  private pipeline: HomeworkImportPipeline | null = null;
  private readonly drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance;

  private constructor() {}

  configure(extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser): void {
    this.pipeline = new HomeworkImportPipeline(extractor, parser);
  }

  private normalizeCandidateDates(candidates: CandidateAssignment[]): CandidateAssignment[] {
    for (let candidate of candidates) {
      if (candidate.dueText.trim().length === 0) candidate.dueText = '今天';
    }
    return candidates;
  }

  private async runSmart(input: RawHomeworkImport): Promise<HomeworkImportPipelineResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    let extracted: ExtractedHomeworkText = await this.pipeline.extract(input);
    let remoteCandidates = await HomeworkOrganizerRemoteApi.instance.organize(extracted);
    if (remoteCandidates !== null) {
      return { extracted: extracted, candidates: this.normalizeCandidateDates(remoteCandidates), organizerMode: HomeworkOrganizerMode.AI };
    }
    return {
      extracted: extracted,
      candidates: this.normalizeCandidateDates(await this.pipeline.parse(extracted)),
      organizerMode: HomeworkOrganizerMode.LOCAL
    };
  }

  async parseText(text: string): Promise<HomeworkTextImportResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    let normalized = text.trim();
    if (normalized.length === 0) return { candidateCount: 0, organizerMode: HomeworkOrganizerMode.LOCAL };

    let studentId = this.drafts.getActiveStudentId();
    let rawImport: RawHomeworkImport = {
      id: `text-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: '家长录入文字',
      resourceUri: '',
      rawText: normalized
    };
    let output: HomeworkImportPipelineResult = await this.runSmart(rawImport);
    if (output.candidates.length === 0) {
      return { candidateCount: 0, organizerMode: output.organizerMode };
    }

    this.drafts.replaceRawImport({
      id: rawImport.id,
      studentId: studentId,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: output.extracted.text
    });
    this.drafts.replaceCandidates(output.candidates);
    return { candidateCount: output.candidates.length, organizerMode: output.organizerMode };
  }

  async reparseCurrentImport(): Promise<number> {
    if (this.pipeline === null) return 0;
    let current = this.drafts.getRawImport();
    let output = await this.runSmart(current);
    if (output.candidates.length === 0) return 0;
    this.drafts.replaceRawImport({
      id: current.id,
      studentId: current.studentId,
      sourceKind: current.sourceKind,
      sourceLabel: current.sourceLabel,
      resourceUri: current.resourceUri,
      rawText: output.extracted.text
    });
    this.drafts.replaceCandidates(output.candidates);
    return output.candidates.length;
  }

  async selectImageAndParse(): Promise<HomeworkImageImportResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');

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
      return { selected: false, candidateCount: 0, recognizedText: '', organizerMode: HomeworkOrganizerMode.LOCAL };
    }

    let studentId = this.drafts.getActiveStudentId();
    let rawImport: RawHomeworkImport = {
      id: `image-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: '相册作业截图',
      resourceUri: photoUris[0],
      rawText: ''
    };

    let output: HomeworkImportPipelineResult = await this.runSmart(rawImport);
    this.drafts.replaceRawImport({
      id: rawImport.id,
      studentId: studentId,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: output.extracted.text
    });
    if (output.candidates.length > 0) this.drafts.replaceCandidates(output.candidates);

    return {
      selected: true,
      candidateCount: output.candidates.length,
      recognizedText: output.extracted.text,
      organizerMode: output.organizerMode
    };
  }
}
