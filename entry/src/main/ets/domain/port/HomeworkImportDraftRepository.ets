import { CandidateAssignment, RawHomeworkImport } from '../model/HomeworkModels';

export interface HomeworkImportDraftRepository {
  getActiveStudentId(): string;
  getRawImport(): RawHomeworkImport;
  getCandidates(): CandidateAssignment[];
  replaceRawImport(input: RawHomeworkImport): void;
  replaceCandidates(candidates: CandidateAssignment[]): void;
  updateCandidate(candidate: CandidateAssignment): boolean;
  addCandidate(candidate: CandidateAssignment): boolean;
  removeCandidate(candidateId: string): boolean;
  clearCandidates(): void;
  /**
   * 学生/批次作用域的草稿清理。异步发布返回后再清草稿时，不能只看"当前 active 是谁"：
   * 家长可能已经切到另一个孩子，那样会清掉别人未发布的候选作业（CONTEXT.md 规则 17）。
   */
  clearCandidatesForStudent(studentId: string, batchId: string): void;
}
