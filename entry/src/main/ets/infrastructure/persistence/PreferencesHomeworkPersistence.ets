import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppSettings,
  Assignment,
  CandidateAssignment,
  RawHomeworkImport,
  Submission,
  TutorSession
} from '../../domain/model/HomeworkModels';
import { HomeworkSnapshot } from '../../domain/model/PersistenceModels';
import { HomeworkPersistence } from '../../domain/port/HomeworkPersistence';

const STORE_NAME: string = 'homework_assistant_state';
const SNAPSHOT_KEY: string = 'homework_snapshot_v1';
const SNAPSHOT_BACKUP_KEY: string = 'homework_snapshot_pre_migration_backup';

export class PreferencesHomeworkPersistence implements HomeworkPersistence {
  private readonly context: common.UIAbilityContext;
  private store: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== null) {
      return this.store;
    }

    try {
      let store = await preferences.getPreferences(this.context, STORE_NAME);
      this.store = store;
      return store;
    } catch {
      console.error('Homework local storage initialization failed');
      throw new Error('本地作业存储初始化失败');
    }
  }

  async load(): Promise<HomeworkSnapshot | null> {
    let store = await this.getStore();
    let value: preferences.ValueType;
    try {
      value = await store.get(SNAPSHOT_KEY, '');
    } catch {
      console.error('Homework snapshot read failed');
      throw new Error('本地作业数据读取失败');
    }

    if (typeof value !== 'string' || value.length === 0) {
      return null;
    }

    try {
      let parsed: Record<string, Object> = JSON.parse(value);
      let snapshot: HomeworkSnapshot = {
        schemaVersion: parsed.schemaVersion as number,
        settings: parsed.settings as AppSettings,
        rawImports: parsed.rawImports as RawHomeworkImport[],
        assignments: parsed.assignments as Assignment[],
        candidates: parsed.candidates as CandidateAssignment[],
        submissions: parsed.submissions as Submission[],
        tutorSessions: parsed.tutorSessions as TutorSession[],
        submissionSequence: parsed.submissionSequence as number
      };
      return snapshot;
    } catch {
      console.error('Homework snapshot exists but cannot be parsed; preserving stored value');
      throw new Error('本地作业数据损坏，已停止覆盖原数据');
    }
  }

  private async preservePreMigrationSnapshot(store: preferences.Preferences, snapshot: HomeworkSnapshot): Promise<void> {
    let existing = await store.get(SNAPSHOT_KEY, '');
    if (typeof existing !== 'string' || existing.length === 0) return;

    let existingVersion: number;
    try {
      let parsed: Record<string, Object> = JSON.parse(existing);
      existingVersion = parsed.schemaVersion as number;
      if (!Number.isFinite(existingVersion) || existingVersion <= 0) {
        throw new Error('invalid schema version');
      }
    } catch {
      console.error('Existing homework snapshot cannot be validated before save; preserving original data');
      throw new Error('本地作业数据无法验证，已停止覆盖原数据');
    }

    if (existingVersion === snapshot.schemaVersion) return;

    let backup = await store.get(SNAPSHOT_BACKUP_KEY, '');
    if (typeof backup === 'string' && backup.length > 0) return;
    await store.put(SNAPSHOT_BACKUP_KEY, existing);
  }

  async save(snapshot: HomeworkSnapshot): Promise<void> {
    try {
      let store = await this.getStore();
      await this.preservePreMigrationSnapshot(store, snapshot);
      await store.put(SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch (error) {
      console.error(`Homework snapshot save failed; stored data was not intentionally replaced: ${error}`);
      throw error;
    }
  }
}
