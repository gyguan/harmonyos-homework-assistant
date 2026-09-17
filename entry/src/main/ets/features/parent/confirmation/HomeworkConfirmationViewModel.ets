import { HomeworkBatchPublishResult, HomeworkBatchPublishService } from '../../../application/import/HomeworkBatchPublishService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import { CandidateAssignment, RawHomeworkImport, Subject } from '../../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../../domain/port/HomeworkImportDraftRepository';

export class HomeworkConfirmationViewModel {
  private readonly drafts: HomeworkImportDraftRepository;

  constructor(drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance) {
    this.drafts = drafts;
  }

  candidates(): CandidateAssignment[] { return this.drafts.getCandidates(); }
  rawImport(): RawHomeworkImport { return this.drafts.getRawImport(); }

  updateCandidate(candidate: CandidateAssignment): boolean { return this.drafts.updateCandidate(candidate); }
  removeCandidate(candidateId: string): boolean { return this.drafts.removeCandidate(candidateId); }

  addCandidate(): CandidateAssignment | null {
    let raw = this.rawImport();
    let candidate: CandidateAssignment = {
      id: `manual-${Date.now()}`,
      studentId: this.drafts.getActiveStudentId(),
      subject: Subject.CHINESE,
      title: '新作业',
      instruction: '新作业',
      textbookRef: '待家长确认',
      dueText: '今天',
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: raw.sourceLabel.length > 0 ? raw.sourceLabel : '家长手工新增',
        excerpt: '家长手工新增'
      },
      confidence: 1.0
    };
    return this.drafts.addCandidate(candidate) ? candidate : null;
  }

  publish(): Promise<HomeworkBatchPublishResult> {
    return HomeworkBatchPublishService.instance.publish(this.candidates());
  }
}
