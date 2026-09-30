import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import { HomeworkImageImportResult, HomeworkImageTextResult, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport, Subject } from '../../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../../domain/port/HomeworkImportDraftRepository';

export class HomeworkImportViewModel {
  private readonly drafts: HomeworkImportDraftRepository;

  constructor(drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance) {
    this.drafts = drafts;
  }

  rawImport(): RawHomeworkImport { return this.drafts.getRawImport(); }
  candidates(): CandidateAssignment[] { return this.drafts.getCandidates(); }
  activeStudentId(): string { return this.drafts.getActiveStudentId(); }
  parseText(text: string, subject: Subject | null = null, imageRef: string = '',
    imageSourceLabel: string = ''): Promise<HomeworkTextImportResult> {
    return HomeworkImportService.instance.parseText(text, subject, imageRef, imageSourceLabel);
  }
  captureImageText(): Promise<HomeworkImageTextResult> {
    return HomeworkImportService.instance.captureImageText();
  }
  selectImageText(): Promise<HomeworkImageTextResult> { return HomeworkImportService.instance.selectImageText(); }
  selectImageAndParse(): Promise<HomeworkImageImportResult> { return HomeworkImportService.instance.selectImageAndParse(); }
  selectImage(): Promise<string> { return HomeworkImportService.instance.selectImage(); }
  captureImage(): Promise<string> { return HomeworkImportService.instance.captureImage(); }
  recognizeSelectedImageText(imageRef: string, sourceLabel: string): Promise<HomeworkImageTextResult> {
    return HomeworkImportService.instance.recognizeSelectedImageText(imageRef, sourceLabel);
  }
  parseImage(imageRef: string, subject: Subject | null, sourceLabel: string,
    text: string = ''): Promise<HomeworkTextImportResult> {
    return HomeworkImportService.instance.parseImage(imageRef, subject, sourceLabel, text);
  }
}
