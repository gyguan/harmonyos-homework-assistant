import { Assignment, AssignmentBacking, AssignmentContentType, AssignmentType, Subject } from '../model/HomeworkModels';
import { HomeworkSnapshot } from '../model/PersistenceModels';

export const HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 9;

export class HomeworkSnapshotMigrator {
  static migrate(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    HomeworkSnapshotMigrator.validateSnapshot(snapshot);
    if (snapshot.schemaVersion > HOMEWORK_SNAPSHOT_SCHEMA_VERSION) {
      throw new Error(`不支持的本地作业数据版本: ${snapshot.schemaVersion}`);
    }
    if (snapshot.schemaVersion < 4) {
      throw new Error(`缺少本地作业数据迁移路径: ${snapshot.schemaVersion} -> ${HOMEWORK_SNAPSHOT_SCHEMA_VERSION}`);
    }

    let current: HomeworkSnapshot = snapshot;
    while (current.schemaVersion < HOMEWORK_SNAPSHOT_SCHEMA_VERSION) {
      if (current.schemaVersion === 4) {
        current = HomeworkSnapshotMigrator.migrateV4ToV5(current);
        continue;
      }
      if (current.schemaVersion === 5) {
        current = HomeworkSnapshotMigrator.migrateV5ToV6(current);
        continue;
      }
      if (current.schemaVersion === 6) {
        current = HomeworkSnapshotMigrator.migrateV6ToV7(current);
        continue;
      }
      if (current.schemaVersion === 7) {
        current = HomeworkSnapshotMigrator.migrateV7ToV8(current);
        continue;
      }
      if (current.schemaVersion === 8) {
        current = HomeworkSnapshotMigrator.migrateV8ToV9(current);
        continue;
      }
      throw new Error(`缺少本地作业数据迁移步骤: ${current.schemaVersion}`);
    }
    HomeworkSnapshotMigrator.validateSnapshot(current);
    return current;
  }

  private static migrateV4ToV5(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    return {
      schemaVersion: 5,
      settings: snapshot.settings,
      rawImports: snapshot.rawImports,
      assignments: snapshot.assignments,
      candidates: snapshot.candidates,
      submissions: snapshot.submissions,
      tutorSessions: snapshot.tutorSessions,
      submissionSequence: snapshot.submissionSequence
    };
  }

  private static migrateV5ToV6(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    let assignments: Assignment[] = [];
    for (let source of snapshot.assignments) {
      assignments.push({
        id: source.id,
        studentId: source.studentId,
        candidateId: source.candidateId,
        backing: HomeworkSnapshotMigrator.legacyBacking(source),
        assignmentType: AssignmentType.SCHOOL,
        subjectCode: HomeworkSnapshotMigrator.subjectCode(source.subject),
        contentType: AssignmentContentType.NORMAL,
        subject: source.subject,
        title: source.title,
        instruction: source.instruction,
        textbookRef: source.textbookRef,
        dueAtEpochMs: 0,
        dueTimezone: 'Asia/Shanghai',
        dueText: source.dueText,
        dueDateKey: source.dueDateKey,
        status: source.status,
        expectedMinutes: source.expectedMinutes,
        startedAtEpochMs: source.startedAtEpochMs,
        finishedAtEpochMs: source.finishedAtEpochMs,
        elapsedSeconds: source.elapsedSeconds,
        reviewNote: source.reviewNote,
        remoteVersion: source.remoteVersion,
        syncDirty: source.syncDirty,
        lastSyncedAtEpochMs: source.lastSyncedAtEpochMs,
        resourceLabels: source.resourceLabels.slice()
      });
    }
    return {
      schemaVersion: 6,
      settings: snapshot.settings,
      rawImports: snapshot.rawImports,
      assignments: assignments,
      candidates: snapshot.candidates,
      submissions: snapshot.submissions,
      tutorSessions: snapshot.tutorSessions,
      submissionSequence: snapshot.submissionSequence
    };
  }

  private static migrateV6ToV7(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    let assignments: Assignment[] = [];
    for (let source of snapshot.assignments) {
      assignments.push({
        id: source.id,
        studentId: source.studentId,
        candidateId: source.candidateId,
        backing: HomeworkSnapshotMigrator.legacyBacking(source),
        assignmentType: source.assignmentType,
        subjectCode: source.subjectCode,
        contentType: source.contentType === AssignmentContentType.AUDIO_IMAGE ?
          AssignmentContentType.AUDIO_IMAGE : AssignmentContentType.NORMAL,
        subject: source.subject,
        title: source.title,
        instruction: source.instruction,
        textbookRef: source.textbookRef,
        dueAtEpochMs: source.dueAtEpochMs,
        dueTimezone: source.dueTimezone,
        dueText: source.dueText,
        dueDateKey: source.dueDateKey,
        status: source.status,
        expectedMinutes: source.expectedMinutes,
        startedAtEpochMs: source.startedAtEpochMs,
        finishedAtEpochMs: source.finishedAtEpochMs,
        elapsedSeconds: source.elapsedSeconds,
        reviewNote: source.reviewNote,
        remoteVersion: source.remoteVersion,
        syncDirty: source.syncDirty,
        lastSyncedAtEpochMs: source.lastSyncedAtEpochMs,
        resourceLabels: source.resourceLabels.slice()
      });
    }
    return {
      schemaVersion: 7,
      settings: snapshot.settings,
      rawImports: snapshot.rawImports,
      assignments: assignments,
      candidates: snapshot.candidates,
      submissions: snapshot.submissions,
      tutorSessions: snapshot.tutorSessions,
      submissionSequence: snapshot.submissionSequence
    };
  }

  private static migrateV7ToV8(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    let assignments: Assignment[] = [];
    for (let source of snapshot.assignments) {
      assignments.push({
        id: source.id,
        studentId: source.studentId,
        candidateId: source.candidateId,
        backing: HomeworkSnapshotMigrator.legacyBacking(source),
        assignmentType: source.assignmentType,
        subjectCode: source.subjectCode,
        contentType: source.contentType === AssignmentContentType.AUDIO_IMAGE ?
          AssignmentContentType.AUDIO_IMAGE : AssignmentContentType.NORMAL,
        subject: source.subject,
        title: source.title,
        instruction: source.instruction,
        textbookRef: source.textbookRef,
        dueAtEpochMs: source.dueAtEpochMs,
        dueTimezone: source.dueTimezone,
        dueText: source.dueText,
        dueDateKey: source.dueDateKey,
        status: source.status,
        expectedMinutes: source.expectedMinutes,
        startedAtEpochMs: source.startedAtEpochMs,
        finishedAtEpochMs: source.finishedAtEpochMs,
        elapsedSeconds: source.elapsedSeconds,
        reviewNote: source.reviewNote,
        remoteVersion: source.remoteVersion,
        syncDirty: source.syncDirty,
        lastSyncedAtEpochMs: source.lastSyncedAtEpochMs,
        resourceLabels: source.resourceLabels.slice()
      });
    }
    return {
      schemaVersion: 8,
      settings: snapshot.settings,
      rawImports: snapshot.rawImports,
      assignments: assignments,
      candidates: snapshot.candidates,
      submissions: snapshot.submissions,
      tutorSessions: snapshot.tutorSessions,
      submissionSequence: snapshot.submissionSequence
    };
  }

  private static migrateV8ToV9(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    return {
      schemaVersion: 9,
      settings: {
        students: snapshot.settings.students,
        activeStudentId: snapshot.settings.activeStudentId,
        parentAccessCode: '',
        tutorGuidanceFirst: snapshot.settings.tutorGuidanceFirst,
        directAnswerAllowed: snapshot.settings.directAnswerAllowed
      },
      rawImports: snapshot.rawImports,
      assignments: snapshot.assignments,
      candidates: snapshot.candidates,
      submissions: snapshot.submissions,
      tutorSessions: snapshot.tutorSessions,
      submissionSequence: snapshot.submissionSequence
    };
  }

  private static legacyBacking(source: Assignment): AssignmentBacking {
    if (source.backing === AssignmentBacking.REMOTE) return AssignmentBacking.REMOTE;
    if (source.remoteVersion > 0 || source.candidateId.length > 0) return AssignmentBacking.REMOTE;
    if (source.id.indexOf('a-extra-') === 0 || source.id.indexOf('a-voice-') === 0 ||
      source.id.indexOf('a-published-') === 0) {
      return AssignmentBacking.REMOTE;
    }
    return AssignmentBacking.LOCAL_SEED;
  }

  private static subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }

  private static validateSnapshot(snapshot: HomeworkSnapshot): void {
    if (!Number.isFinite(snapshot.schemaVersion) || snapshot.schemaVersion <= 0) {
      throw new Error('本地作业数据缺少有效 schemaVersion');
    }
    if (snapshot.settings === undefined || snapshot.settings === null) {
      throw new Error('本地作业数据缺少 settings');
    }
    if (!Array.isArray(snapshot.rawImports) || !Array.isArray(snapshot.assignments) ||
      !Array.isArray(snapshot.candidates) || !Array.isArray(snapshot.submissions) ||
      !Array.isArray(snapshot.tutorSessions)) {
      throw new Error('本地作业数据结构不完整');
    }
    if (snapshot.schemaVersion >= 8) {
      for (let assignment of snapshot.assignments) {
        if (assignment.backing !== AssignmentBacking.LOCAL_SEED &&
          assignment.backing !== AssignmentBacking.REMOTE) {
          throw new Error(`本地作业数据缺少有效 backing: ${assignment.id}`);
        }
      }
    }
  }
}
