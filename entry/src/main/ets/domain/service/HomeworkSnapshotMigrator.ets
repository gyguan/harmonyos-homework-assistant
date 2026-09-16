import { HomeworkSnapshot } from '../model/PersistenceModels';

export const HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 5;

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
      throw new Error(`缺少本地作业数据迁移步骤: ${current.schemaVersion}`);
    }
    HomeworkSnapshotMigrator.validateSnapshot(current);
    return current;
  }

  private static migrateV4ToV5(snapshot: HomeworkSnapshot): HomeworkSnapshot {
    // V5 introduces the explicit migration framework. The persisted business shape is unchanged;
    // future schema changes must add one deterministic step here instead of resetting local data.
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
  }
}
