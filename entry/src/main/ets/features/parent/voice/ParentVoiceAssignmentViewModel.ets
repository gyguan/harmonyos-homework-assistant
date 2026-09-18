import { RemoteAssignmentResourceApi } from '../../../application/remote/RemoteAssignmentResourceApi';
import { RemoteAssignmentMapper } from '../../../application/remote/RemoteModels';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  Assignment,
  AssignmentContentType,
  AssignmentStatus,
  AssignmentType,
  StudentProfile,
  Subject
} from '../../../domain/model/HomeworkModels';

export interface VoiceAssignmentDraft {
  subject: Subject;
  title: string;
  instruction: string;
  dueAtEpochMs: number;
  dueText: string;
  expectedMinutes: number;
}

export class ParentVoiceAssignmentViewModel {
  private readonly repository: DefaultAssignmentRepository;

  constructor(repository: DefaultAssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  async create(draft: VoiceAssignmentDraft, audioUri: string, imageUris: string[]): Promise<Assignment> {
    let student = this.student();
    let assignment: Assignment = {
      id: `a-voice-${student.id}-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
      studentId: student.id,
      candidateId: '',
      assignmentType: AssignmentType.EXTRA,
      subjectCode: this.subjectCode(draft.subject),
      contentType: AssignmentContentType.AUDIO_IMAGE,
      subject: draft.subject,
      title: draft.title.trim(),
      instruction: draft.instruction.trim(),
      textbookRef: '',
      dueAtEpochMs: draft.dueAtEpochMs,
      dueTimezone: 'Asia/Shanghai',
      dueText: draft.dueText,
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: draft.expectedMinutes,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    };

    let result = await RemoteAssignmentResourceApi.instance.createVoiceAssignment(
      assignment, audioUri, imageUris);
    let mapped = RemoteAssignmentMapper.toLocal(result.assignment, assignment);
    mapped.resourceLabels = result.resources.map((item) => item.originalName);
    this.repository.applyAuthoritative(mapped);
    return mapped;
  }

  private subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
