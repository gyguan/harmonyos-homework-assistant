import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  HomeworkImportInboxSnapshot,
  ImportBatch,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { CandidateAssignment } from '../../domain/model/HomeworkModels';
import { HomeworkImportInboxPersistence } from '../../domain/port/HomeworkImportInboxPersistence';

const STORE_NAME: string = 'homework_import_inbox_v2';
const SNAPSHOT_KEY: string = 'homework_import_inbox_snapshot_v1';

export class PreferencesHomeworkImportInboxPersistence implements HomeworkImportInboxPersistence {
  private readonly context: common.UIAbilityContext;
  private store: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== null) return this.store;
    try {
      let store = await preferences.getPreferences(this.context, STORE_NAME);
      this.store = store;
      return store;
    } catch {
      throw new Error('作业导入收件箱存储初始化失败');
    }
  }

  async load(): Promise<HomeworkImportInboxSnapshot | null> {
    let store = await this.getStore();
    let value: preferences.ValueType;
    try {
      value = await store.get(SNAPSHOT_KEY, '');
    } catch {
      throw new Error('作业导入收件箱读取失败');
    }
    if (typeof value !== 'string' || value.length === 0) return null;

    try {
      let parsed: Record<string, Object> = JSON.parse(value);
      return {
        schemaVersion: parsed.schemaVersion as number,
        activeBatchId: parsed.activeBatchId as string,
        batches: parsed.batches as ImportBatch[],
        messages: parsed.messages as ImportedMessage[],
        candidates: parsed.candidates as CandidateAssignment[]
      };
    } catch {
      throw new Error('作业导入收件箱数据损坏，已停止覆盖原数据');
    }
  }

  async save(snapshot: HomeworkImportInboxSnapshot): Promise<void> {
    let store = await this.getStore();
    try {
      await store.put(SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch {
      console.error('Homework import inbox save failed; in-memory state remains available');
    }
  }
}
