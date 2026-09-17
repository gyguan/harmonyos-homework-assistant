import { BackendSession } from '../remote/BackendSession';
import {
  BatchPublishEntry,
  HomeworkRemoteApi,
  RemoteBatchPublishResponse
} from '../remote/HomeworkRemoteApi';
import { RemoteAssignmentMapper } from '../remote/RemoteModels';
import { HomeworkStore } from '../../data/HomeworkStore';
import { DefaultAssignmentRepository } from '../../data/repository/DefaultAssignmentRepository';
import {
  Assignment,
  AssignmentStatus,
  AssignmentType,
  CandidateAssignment,
  Subject
} from '../../domain/model/HomeworkModels';

export interface HomeworkBatchPublishResult {
  publishedCount: number;
}

export class HomeworkBatchPublishService {
  static readonly instance: HomeworkBatchPublishService = new HomeworkBatchPublishService();

  private constructor() {}

  async publish(candidates: CandidateAssignment[]): Promise<HomeworkBatchPublishResult> {
    if (candidates.length === 0) throw new Error('没有待发布作业');
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，连接家庭云端后才能发布作业');
    }

    let studentId = HomeworkStore.instance.getActiveStudentId();
    let entries: BatchPublishEntry[] = [];
    let localByCandidateId: Map<string, Assignment> = new Map<string, Assignment>();
    for (let candidate of candidates) {
      if (candidate.studentId !== studentId) throw new Error('待发布作业不属于当前孩子');
      let assignment = this.toAssignment(candidate);
      entries.push({ candidateId: candidate.id, assignment: assignment });
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

    // Only after the full atomic response has been validated may local Assignment/Candidate state move.
    for (let assignment of mapped) DefaultAssignmentRepository.instance.applyAuthoritative(assignment);
    HomeworkStore.instance.replaceCandidates([]);
    return { publishedCount: mapped.length };
  }

  private toAssignment(candidate: CandidateAssignment): Assignment {
    return {
      id: `a-published-${candidate.id}`,
      studentId: candidate.studentId,
      candidateId: candidate.id,
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: this.subjectCode(candidate.subject),
      subject: candidate.subject,
      title: candidate.title,
      instruction: candidate.instruction,
      textbookRef: candidate.textbookRef,
      dueAtEpochMs: 0,
      dueTimezone: 'Asia/Shanghai',
      dueText: candidate.dueText,
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

  private subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
