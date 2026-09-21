import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  CaptureFrameEvidence,
  CaptureSession,
  HomeworkCaptureSessionSnapshot
} from '../../domain/model/CaptureModels';
import { HomeworkCaptureSessionPersistence } from '../../domain/port/HomeworkCaptureSessionPersistence';

const STORE_NAME: string = 'homework_capture_sessions_v1';
const SNAPSHOT_KEY: string = 'homework_capture_session_snapshot_v1';

export class PreferencesHomeworkCaptureSessionPersistence implements HomeworkCaptureSessionPersistence {
  private readonly context: common.Context;
  private store: preferences.Preferences | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== null) return this.store;
    try {
      let store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      this.store = store;
      return store;
    } catch {
      throw new Error('无法打开采集会话本地存储');
    }
  }

  async load(): Promise<HomeworkCaptureSessionSnapshot | null> {
    let store: preferences.Preferences = await this.getStore();
    try {
      let value = await store.get(SNAPSHOT_KEY, '');
      if (typeof value !== 'string' || value.length === 0) return null;
      let parsed: Record<string, Object> = JSON.parse(value);
      return {
        schemaVersion: parsed.schemaVersion as number,
        activeSessionId: parsed.activeSessionId as string,
        sessions: parsed.sessions as CaptureSession[],
        evidence: parsed.evidence as CaptureFrameEvidence[]
      };
    } catch {
      throw new Error('采集会话本地数据损坏，已停止覆盖原数据');
    }
  }

  async save(snapshot: HomeworkCaptureSessionSnapshot): Promise<void> {
    let store: preferences.Preferences = await this.getStore();
    try {
      await store.put(SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch {
      throw new Error('无法保存采集会话本地数据');
    }
  }
}
