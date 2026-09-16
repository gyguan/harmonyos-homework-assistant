import { Assignment, AssignmentStatus, AssignmentType, Subject } from '../../domain/model/HomeworkModels';

export interface RemoteAssignment {
  id: string;
  studentId: string;
  assignmentType: string;
  subjectCode: string;
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  dueAtEpochMs: number;
  dueTimezone: string;
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
      assignmentType: remote.assignmentType === AssignmentType.EXTRA ? AssignmentType.EXTRA : AssignmentType.SCHOOL,
      subjectCode: remote.subjectCode === undefined || remote.subjectCode.length === 0 ?
        RemoteAssignmentMapper.subjectCode(remote.subject as Subject) : remote.subjectCode,
      subject: remote.subject as Subject,
      title: remote.title,
      instruction: remote.instruction,
      textbookRef: remote.textbookRef,
      dueAtEpochMs: remote.dueAtEpochMs > 0 ? remote.dueAtEpochMs : 0,
      dueTimezone: remote.dueTimezone === undefined || remote.dueTimezone.length === 0 ? 'Asia/Shanghai' : remote.dueTimezone,
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

  private static subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
