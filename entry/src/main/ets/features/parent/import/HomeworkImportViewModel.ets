import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import { HomeworkImageImportResult, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../../domain/port/HomeworkImportDraftRepository';

export class HomeworkImportViewModel {
  private readonly drafts: HomeworkImportDraftRepository;

  constructor(drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance) {
    this.drafts = drafts;
  }

  rawImport(): RawHomeworkImport { return this.drafts.getRawImport(); }
  candidates(): CandidateAssignment[] { return this.drafts.getCandidates(); }
  parseText(text: string): Promise<HomeworkTextImportResult> { return HomeworkImportService.instance.parseText(text); }
  selectImageAndParse(): Promise<HomeworkImageImportResult> { return HomeworkImportService.instance.selectImageAndParse(); }
}
