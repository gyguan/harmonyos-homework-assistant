import { RemoteAssignmentResourceApi } from '../../../application/remote/RemoteAssignmentResourceApi';
import { RemoteAssignmentMapper } from '../../../application/remote/RemoteModels';
import {
  RemoteVoiceFolderItem,
  RemoteVoiceFolderPage,
  RemoteVoiceMaterialApi,
  RemoteVoiceMaterialCreateAssignmentRequest
} from '../../../application/remote/RemoteVoiceMaterialApi';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  Assignment,
  AssignmentBacking,
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

  queryFolders(keyword: string, usage: string, page: number, size: number = 20):
    Promise<RemoteVoiceFolderPage> {
    return RemoteVoiceMaterialApi.instance.queryFolders(
      this.student().id, keyword, usage, page, size);
  }

  async createFromFolder(draft: VoiceAssignmentDraft, folder: RemoteVoiceFolderItem,
    requestId: string): Promise<Assignment | null> {
    let request: RemoteVoiceMaterialCreateAssignmentRequest = {
      studentId: this.student().id,
      expectedMinutes: draft.expectedMinutes,
      dueAtEpochMs: draft.dueAtEpochMs,
      dueText: draft.dueText,
      title: draft.title.trim(),
      instruction: draft.instruction.trim(),
      requestId: requestId
    };
    let result = await RemoteVoiceMaterialApi.instance.createAssignment(folder.packageId, request);
    if (result.assignment === null) return null;
    let existing = this.repository.getCached(result.assignment.id);
    let mapped = RemoteAssignmentMapper.toLocal(result.assignment, existing);
    this.repository.applyAuthoritative(mapped);
    return mapped;
  }

  async create(draft: VoiceAssignmentDraft, audioUri: string, imageUris: string[]): Promise<Assignment> {
    let student = this.student();
    let assignment: Assignment = {
      id: `a-voice-${student.id}-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
      studentId: student.id,
      candidateId: '',
      backing: AssignmentBacking.REMOTE,
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

  subjectFromCode(subjectCode: string): Subject {
    if (subjectCode === 'CHINESE') return Subject.CHINESE;
    if (subjectCode === 'MATH') return Subject.MATH;
    if (subjectCode === 'ENGLISH') return Subject.ENGLISH;
    return Subject.OTHER;
  }

  private subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
