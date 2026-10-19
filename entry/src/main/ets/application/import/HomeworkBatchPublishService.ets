import { BackendSession } from '../remote/BackendSession';
import { HomeworkOrganizerRemoteApi } from '../remote/HomeworkOrganizerRemoteApi';
import { HomeworkImportInboxService } from './HomeworkImportInboxService';
import {
  BatchPublishEntry,
  HomeworkRemoteApi,
  RemoteBatchPublishResponse
} from '../remote/HomeworkRemoteApi';
import { RemoteAssignmentMapper } from '../remote/RemoteModels';
import { DefaultAssignmentRepository } from '../../data/repository/DefaultAssignmentRepository';
import { DefaultHomeworkImportDraftRepository } from '../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  Assignment,
  AssignmentBacking,
  AssignmentContentType,
  AssignmentStatus,
  AssignmentType,
  CandidateAssignment,
  Subject
} from '../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';

export interface HomeworkBatchPublishResult {
  publishedCount: number;
  assignments: Assignment[];
}

export class HomeworkBatchPublishService {
  static readonly instance: HomeworkBatchPublishService = new HomeworkBatchPublishService();

  private readonly drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance;

  private constructor() {}

  async publish(candidates: CandidateAssignment[]): Promise<HomeworkBatchPublishResult> {
    if (candidates.length === 0) throw new Error('没有待发布作业');
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，连接家庭云端后才能发布作业');
    }

    let studentId = this.drafts.getActiveStudentId();
    let batchId = this.sourceBatchId(candidates[0]);
    let entries: BatchPublishEntry[] = [];
    let localByCandidateId: Map<string, Assignment> = new Map<string, Assignment>();
    for (let candidate of candidates) {
      if (candidate.studentId !== studentId) throw new Error('待发布作业不属于当前孩子');
      let candidateBatchId = this.sourceBatchId(candidate);
      if (candidateBatchId !== batchId) throw new Error('待发布作业不属于同一导入批次');
      let assignment = this.toAssignment(candidate);
      entries.push({
        candidateId: candidate.id,
        assignment: assignment,
        sourceLabel: candidate.sourceEvidence.sourceLabel,
        sourceExcerpt: this.sourceEvidenceText(candidate)
      });
      localByCandidateId.set(candidate.id, assignment);
    }

    let response: RemoteBatchPublishResponse = await HomeworkRemoteApi.instance.batchPublish(studentId, entries);
    if (!response.atomic || response.publishedCount !== candidates.length || response.results.length !== candidates.length) {
      throw new Error('云端未确认整批发布完成，请刷新后重试');
    }

    let mapped: Assignment[] = [];
    let seen: Set<string> = new Set<string>();
    for (let result of response.results) {
      let local = localByCandidateId.get(result.candidateId);
      if (local === undefined || seen.has(result.candidateId)) {
        throw new Error('云端批量发布响应与本地待确认作业不一致');
      }
      seen.add(result.candidateId);
      mapped.push(RemoteAssignmentMapper.toLocal(result.assignment, local));
    }
    if (seen.size !== candidates.length) throw new Error('云端批量发布响应不完整');

    let inbox = HomeworkImportInboxService.instance;
    let clearCurrentDraft = false;
    let activeStudentId = this.drafts.getActiveStudentId();
    if (activeStudentId === studentId) {
      let activeBatchId = inbox.getActiveBatchId();
      if (activeBatchId === batchId) clearCurrentDraft = true;
    }
    DefaultAssignmentRepository.instance.applyAuthoritativeBatch(mapped);
    inbox.markBatchPublished(batchId);
    // 只在服务端确认成功发布后学习家长纠错；学习接口与发布解耦，不能阻断作业。
    void HomeworkOrganizerRemoteApi.instance.reportConfirmedEdits(candidates).catch(() => {});
    if (clearCurrentDraft) this.drafts.clearCandidates();
    return { publishedCount: mapped.length, assignments: mapped.slice() };
  }

  private sourceEvidenceText(candidate: CandidateAssignment): string {
    let rawText = candidate.sourceEvidence.rawText;
    if (rawText !== undefined && rawText.trim().length > 0) return rawText.trim();
    return candidate.sourceEvidence.excerpt.trim();
  }

  private sourceBatchId(candidate: CandidateAssignment): string {
    let batchId = candidate.sourceEvidence.batchId;
    if (batchId === undefined) return '';
    return batchId;
  }

  private toAssignment(candidate: CandidateAssignment): Assignment {
    return {
      id: `a-published-${candidate.id}`,
      studentId: candidate.studentId,
      candidateId: candidate.id,
      backing: AssignmentBacking.REMOTE,
      assignmentType: this.assignmentType(candidate.subject),
      subjectCode: this.subjectCode(candidate.subject),
      contentType: AssignmentContentType.NORMAL,
      subject: candidate.subject,
      title: candidate.title,
      instruction: candidate.instruction,
      textbookRef: candidate.textbookRef,
      taskDate: candidate.taskDate,
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: candidate.expectedMinutes > 0 ? candidate.expectedMinutes : 20,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    };
  }

  private assignmentType(subject: Subject): AssignmentType {
    if (subject === Subject.CHINESE || subject === Subject.MATH || subject === Subject.ENGLISH) {
      return AssignmentType.SCHOOL;
    }
    return AssignmentType.EXTRA;
  }

  private subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
