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
      resourceLabels: existing === null ? [] : existing.resourceLabels.slice()
    };
  }
}
