import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  HomeworkSourceProfile,
  HomeworkSourceProfileSnapshot
} from '../../domain/model/HomeworkSourceProfileModels';
import { HomeworkSourceProfilePersistence } from '../../domain/port/HomeworkSourceProfilePersistence';

const STORE_NAME: string = 'homework_source_profiles_v1';
const SNAPSHOT_KEY: string = 'homework_source_profiles_snapshot_v1';

export class PreferencesHomeworkSourceProfilePersistence implements HomeworkSourceProfilePersistence {
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
      throw new Error('无法打开班级采集配置本地存储');
    }
  }

  async load(): Promise<HomeworkSourceProfileSnapshot | null> {
    let store: preferences.Preferences = await this.getStore();
    try {
      let value = await store.get(SNAPSHOT_KEY, '');
      if (typeof value !== 'string' || value.length === 0) return null;
      let parsed: Record<string, Object> = JSON.parse(value);
      return {
        schemaVersion: parsed.schemaVersion as number,
        profiles: parsed.profiles as HomeworkSourceProfile[]
      };
    } catch {
      throw new Error('班级采集配置本地数据损坏，已停止覆盖原数据');
    }
  }

  async save(snapshot: HomeworkSourceProfileSnapshot): Promise<void> {
    let store: preferences.Preferences = await this.getStore();
    try {
      await store.put(SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch {
      throw new Error('无法保存班级采集配置');
    }
  }
}
