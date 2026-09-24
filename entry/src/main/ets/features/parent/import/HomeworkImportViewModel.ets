import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import { HomeworkImageImportResult, HomeworkImageTextResult, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../../domain/port/HomeworkImportDraftRepository';

export class HomeworkImportViewModel {
  private readonly drafts: HomeworkImportDraftRepository;

  constructor(drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance) {
    this.drafts = drafts;
  }

  rawImport(): RawHomeworkImport { return this.drafts.getRawImport(); }
  candidates(): CandidateAssignment[] { return this.drafts.getCandidates(); }
  parseText(text: string, imageRef: string = '',
    imageSourceLabel: string = ''): Promise<HomeworkTextImportResult> {
    return HomeworkImportService.instance.parseText(text, imageRef, imageSourceLabel);
  }
  captureImageText(): Promise<HomeworkImageTextResult> {
    return HomeworkImportService.instance.captureImageText();
  }
  selectImageText(): Promise<HomeworkImageTextResult> { return HomeworkImportService.instance.selectImageText(); }
  selectImageAndParse(): Promise<HomeworkImageImportResult> { return HomeworkImportService.instance.selectImageAndParse(); }
}
