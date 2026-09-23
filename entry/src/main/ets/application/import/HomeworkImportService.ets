import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkOrganizerRemoteApi } from '../remote/HomeworkOrganizerRemoteApi';
import { HomeworkImportInboxService } from './HomeworkImportInboxService';
import { DefaultHomeworkImportDraftRepository } from '../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  ExtractedHomeworkText,
  HomeworkImageImportResult,
  HomeworkImageTextResult,
  HomeworkImportPipelineResult,
  HomeworkImportSourceType,
  HomeworkOrganizerMode,
  HomeworkTextImportResult
} from '../../domain/model/ImportModels';
import { CandidateAssignment, HomeworkImportSourceKind, RawHomeworkImport, Subject } from '../../domain/model/HomeworkModels';
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

  async parseImportedSource(input: RawHomeworkImport): Promise<HomeworkImportPipelineResult> {
    return await this.runSmart(input);
  }

  async parseText(text: string, imageRef: string = ''): Promise<HomeworkTextImportResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    let normalized = text.trim();
    if (normalized.length === 0) return { candidateCount: 0, organizerMode: HomeworkOrganizerMode.LOCAL };

    let studentId = this.drafts.getActiveStudentId();
    let fromScreenshot = imageRef.trim().length > 0;
    let rawImport: RawHomeworkImport = {
      id: `${fromScreenshot ? 'image-text' : 'text'}-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: fromScreenshot ? '相册作业截图' : '家长录入文字',
      resourceUri: fromScreenshot ? imageRef : '',
      rawText: normalized
    };
    let output: HomeworkImportPipelineResult = await this.runSmart(rawImport);
    let candidates = output.candidates.length > 0 ?
      output.candidates : [this.fallbackCandidate(studentId, normalized, rawImport.sourceLabel)];
    HomeworkImportInboxService.instance.commitParsedImport(
      rawImport,
      fromScreenshot ? HomeworkImportSourceType.SCREENSHOT : HomeworkImportSourceType.CLIPBOARD,
      output.extracted.text,
      candidates,
      fromScreenshot ? imageRef : '');
    return { candidateCount: candidates.length, organizerMode: output.organizerMode };
  }

  async selectImageText(): Promise<HomeworkImageTextResult> {
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
      return { selected: false, recognizedText: '', imageRef: '' };
    }

    let rawImport: RawHomeworkImport = {
      id: `image-preview-${Date.now()}`,
      studentId: this.drafts.getActiveStudentId(),
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: '相册作业截图',
      resourceUri: photoUris[0],
      rawText: ''
    };
    let extracted = await this.pipeline.extract(rawImport);
    return {
      selected: true,
      recognizedText: extracted.text,
      imageRef: photoUris[0]
    };
  }

  private fallbackSubject(text: string): Subject {
    if (text.indexOf('跳绳') >= 0 || text.indexOf('跑步') >= 0 || text.indexOf('运动') >= 0 ||
      text.indexOf('体育') >= 0 || text.indexOf('锻炼') >= 0) return Subject.SPORTS;
    if (text.indexOf('朗读') >= 0 || text.indexOf('朗诵') >= 0) return Subject.READ_ALOUD;
    if (text.indexOf('阅读') >= 0 || text.indexOf('读书') >= 0) return Subject.READING;
    if (text.indexOf('实践') >= 0 || text.indexOf('实验') >= 0 || text.indexOf('劳动') >= 0) {
      return Subject.PRACTICE;
    }
    if (text.indexOf('兴趣') >= 0 || text.indexOf('画画') >= 0 || text.indexOf('绘画') >= 0 ||
      text.indexOf('音乐') >= 0) return Subject.INTEREST;
    return Subject.OTHER;
  }

  private fallbackCandidate(studentId: string, text: string, sourceLabel: string): CandidateAssignment {
    let firstLine = text.split('\n')[0].trim();
    let title = firstLine.length > 0 ? firstLine : text;
    if (title.length > 40) title = title.substring(0, 40);
    return {
      id: `manual-fallback-${Date.now()}`,
      studentId: studentId,
      subject: this.fallbackSubject(text),
      title: title,
      instruction: text,
      textbookRef: '',
      dueText: '今天',
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: sourceLabel,
        excerpt: text.substring(0, Math.min(120, text.length))
      },
      confidence: 0.3
    };
  }

  async reparseCurrentImport(): Promise<number> {
    if (this.pipeline === null) return 0;
    let current = this.drafts.getRawImport();
    let output = await this.runSmart(current);
    if (output.candidates.length === 0) return 0;
    let sourceType = current.sourceKind === HomeworkImportSourceKind.IMAGE ?
      HomeworkImportSourceType.SCREENSHOT : HomeworkImportSourceType.CLIPBOARD;
    HomeworkImportInboxService.instance.commitParsedImport(
      current, sourceType, output.extracted.text, output.candidates, current.resourceUri);
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
    HomeworkImportInboxService.instance.commitParsedImport(
      rawImport, HomeworkImportSourceType.SCREENSHOT, output.extracted.text,
      output.candidates, rawImport.resourceUri);

    return {
      selected: true,
      candidateCount: output.candidates.length,
      recognizedText: output.extracted.text,
      organizerMode: output.organizerMode
    };
  }
}
