import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
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

  private context: common.UIAbilityContext | null = null;
  private pipeline: HomeworkImportPipeline | null = null;
  private readonly drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance;

  private constructor() {}

  configure(context: common.UIAbilityContext,
    extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser): void {
    this.context = context;
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

  async parseText(text: string, subject: Subject | null = null, imageRef: string = '',
    imageSourceLabel: string = ''): Promise<HomeworkTextImportResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    let normalized = text.trim();
    if (normalized.length === 0) return { candidateCount: 0, organizerMode: HomeworkOrganizerMode.LOCAL };

    let studentId = this.drafts.getActiveStudentId();
    let fromScreenshot = imageRef.trim().length > 0;
    let rawImport: RawHomeworkImport = {
      id: `${fromScreenshot ? 'image-text' : 'text'}-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: fromScreenshot ?
        (imageSourceLabel.trim().length > 0 ? imageSourceLabel.trim() : '相册作业截图') :
        '家长录入文字',
      resourceUri: fromScreenshot ? imageRef : '',
      rawText: normalized
    };
    let output: HomeworkImportPipelineResult = await this.runSmart(rawImport);
    let candidates = this.applySelectedSubject(output.candidates, subject);
    if (candidates.length === 0 && output.organizerMode === HomeworkOrganizerMode.LOCAL) {
      candidates = [this.fallbackCandidate(studentId, normalized, rawImport.sourceLabel, subject === null ? Subject.OTHER : subject)];
    }
    HomeworkImportInboxService.instance.commitParsedImport(
      rawImport,
      fromScreenshot ? HomeworkImportSourceType.SCREENSHOT : HomeworkImportSourceType.CLIPBOARD,
      output.extracted.text,
      candidates,
      fromScreenshot ? imageRef : '');
    this.ensureCurrentStudent(studentId);
    return { candidateCount: candidates.length, organizerMode: output.organizerMode };
  }

  async parseImage(imageRef: string, subject: Subject | null = null,
    sourceLabel: string = '相册作业图片', text: string = ''): Promise<HomeworkTextImportResult> {
    let studentId = this.drafts.getActiveStudentId();
    if (imageRef.length === 0) throw new Error('请先拍照或选择图片');
    let rawImport: RawHomeworkImport = {
      id: `ai-image-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: sourceLabel,
      resourceUri: imageRef,
      rawText: text.trim()
    };
    let input: ExtractedHomeworkText = {
      importId: rawImport.id, studentId: studentId, sourceLabel: sourceLabel, text: text.trim()
    };
    let output = await HomeworkOrganizerRemoteApi.instance.organizeImage(input, imageRef);
    let candidates = this.applySelectedSubject(this.normalizeCandidateDates(output.candidates), subject);
    let sourceText = output.recognizedText;
    if (text.trim().length > 0) sourceText += `\n\n补充文字：\n${text.trim()}`;
    HomeworkImportInboxService.instance.commitParsedImport(
      rawImport, HomeworkImportSourceType.SCREENSHOT, sourceText, candidates, imageRef);
    this.ensureCurrentStudent(studentId);
    return { candidateCount: candidates.length, organizerMode: HomeworkOrganizerMode.AI };
  }

  private ensureCurrentStudent(studentId: string): void {
    if (studentId !== this.drafts.getActiveStudentId()) {
      throw new Error('孩子已切换，解析结果已保留在原孩子的导入记录中');
    }
  }

  async captureImageText(): Promise<HomeworkImageTextResult> {
    let studentId = this.drafts.getActiveStudentId();
    let imageRef = await this.captureImage();
    if (imageRef.length === 0) return { selected: false, recognizedText: '', imageRef: '' };
    let result = await this.recognizeImageText(imageRef, '现场拍照', studentId);
    this.ensureCurrentStudent(studentId);
    return result;
  }

  async captureImage(): Promise<string> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    if (this.context === null) throw new Error('拍照识别能力尚未初始化');

    try {
      let profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      let result: cameraPicker.PickerResult = await cameraPicker.pick(
        this.context, [cameraPicker.PickerMediaType.PHOTO], profile);
      return result.resultUri;
    } catch {
      throw new Error('无法打开相机，请重试');
    }
  }

  async selectImageText(): Promise<HomeworkImageTextResult> {
    let studentId = this.drafts.getActiveStudentId();
    let imageRef = await this.selectImage();
    if (imageRef.length === 0) return { selected: false, recognizedText: '', imageRef: '' };
    let result = await this.recognizeImageText(imageRef, '相册作业截图', studentId);
    this.ensureCurrentStudent(studentId);
    return result;
  }

  async selectImage(): Promise<string> {
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

    return photoUris.length === 0 ? '' : photoUris[0];
  }

  async recognizeSelectedImageText(imageRef: string, sourceLabel: string): Promise<HomeworkImageTextResult> {
    let studentId = this.drafts.getActiveStudentId();
    let result = await this.recognizeImageText(imageRef, sourceLabel, studentId);
    this.ensureCurrentStudent(studentId);
    return result;
  }

  private async recognizeImageText(imageRef: string, sourceLabel: string, studentId: string):
    Promise<HomeworkImageTextResult> {
    if (this.pipeline === null) throw new Error('作业导入能力尚未初始化');
    let rawImport: RawHomeworkImport = {
      id: `image-preview-${Date.now()}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: sourceLabel,
      resourceUri: imageRef,
      rawText: ''
    };
    let extracted = await this.pipeline.extract(rawImport);
    return {
      selected: true,
      recognizedText: extracted.text,
      imageRef: imageRef
    };
  }

  private applySelectedSubject(candidates: CandidateAssignment[], subject: Subject | null): CandidateAssignment[] {
    if (subject === null) return candidates;
    let result: CandidateAssignment[] = [];
    for (let candidate of candidates) {
      result.push({
        id: candidate.id,
        studentId: candidate.studentId,
        subject: subject,
        title: candidate.title,
        instruction: candidate.instruction,
        textbookRef: candidate.textbookRef,
        dueText: candidate.dueText,
        expectedMinutes: candidate.expectedMinutes,
        sourceEvidence: candidate.sourceEvidence,
        confidence: candidate.confidence
      });
    }
    return result;
  }

  private fallbackCandidate(studentId: string, text: string, sourceLabel: string,
    subject: Subject): CandidateAssignment {
    let firstLine = text.split('\n')[0].trim();
    let title = firstLine.length > 0 ? firstLine : text;
    if (title.length > 40) title = title.substring(0, 40);
    return {
      id: `manual-fallback-${Date.now()}`,
      studentId: studentId,
      subject: subject,
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
