import { Assignment, AssignmentStatus, Subject } from '../../domain/model/HomeworkModels';

export interface RemoteAssignment {
  id: string;
  studentId: string;
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  status: string;
  sourceLabel: string;
  sourceExcerpt: string;
  expectedMinutes: number;
  startedAtEpochMs: number;
  finishedAtEpochMs: number;
  elapsedSeconds: number;
  reviewNote: string;
  version: number;
}

export class RemoteAssignmentMapper {
  static toLocal(remote: RemoteAssignment, existing: Assignment | null): Assignment {
    return {
      id: remote.id,
      studentId: remote.studentId,
      candidateId: existing === null ? '' : existing.candidateId,
      subject: remote.subject as Subject,
      title: remote.title,
      instruction: remote.instruction,
      textbookRef: remote.textbookRef,
      dueText: remote.dueText,
      status: remote.status as AssignmentStatus,
      expectedMinutes: remote.expectedMinutes > 0 ? remote.expectedMinutes : 20,
      startedAtEpochMs: remote.startedAtEpochMs > 0 ? remote.startedAtEpochMs : 0,
      finishedAtEpochMs: remote.finishedAtEpochMs > 0 ? remote.finishedAtEpochMs : 0,
      elapsedSeconds: remote.elapsedSeconds > 0 ? remote.elapsedSeconds : 0,
      reviewNote: remote.reviewNote === undefined ? '' : remote.reviewNote,
      remoteVersion: remote.version,
      syncDirty: false,
      lastSyncedAtEpochMs: Date.now(),
      resourceLabels: existing === null ? [] : existing.resourceLabels.slice()
    };
  }
}
