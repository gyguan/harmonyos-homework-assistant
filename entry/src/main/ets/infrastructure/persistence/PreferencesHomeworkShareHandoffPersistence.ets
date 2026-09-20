import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PendingHomeworkShareImport } from '../../domain/model/HomeworkShareModels';
import { HomeworkShareHandoffPersistence } from '../../domain/port/HomeworkShareHandoffPersistence';

const STORE_NAME: string = 'homework_share_handoff_v1';
const ITEMS_KEY: string = 'pending_share_imports_v1';
const MAX_AGE_MS: number = 24 * 60 * 60 * 1000;

export class PreferencesHomeworkShareHandoffPersistence implements HomeworkShareHandoffPersistence {
  private readonly context: common.Context;
  private store: preferences.Preferences | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== null) return this.store;
    let store = await preferences.getPreferences(this.context, STORE_NAME);
    this.store = store;
    return store;
  }

  private clone(item: PendingHomeworkShareImport): PendingHomeworkShareImport {
    return {
      token: item.token,
      createdAtEpochMs: item.createdAtEpochMs,
      records: item.records.map(record => ({
        id: record.id,
        kind: record.kind,
        utd: record.utd,
        content: record.content,
        sandboxUri: record.sandboxUri,
        title: record.title
      }))
    };
  }

  private async readItems(): Promise<PendingHomeworkShareImport[]> {
    let store = await this.getStore();
    let raw = await store.get(ITEMS_KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) return [];
    try {
      let parsed = JSON.parse(raw) as PendingHomeworkShareImport[];
      let cutoff = Date.now() - MAX_AGE_MS;
      let result: PendingHomeworkShareImport[] = [];
      for (let item of parsed) {
        if (item.createdAtEpochMs >= cutoff) result.push(this.clone(item));
      }
      return result;
    } catch {
      throw new Error('系统分享暂存数据损坏');
    }
  }

  async list(): Promise<PendingHomeworkShareImport[]> {
    return await this.readItems();
  }

  async find(token: string): Promise<PendingHomeworkShareImport | null> {
    let items = await this.readItems();
    for (let item of items) if (item.token === token) return this.clone(item);
    return null;
  }

  async save(item: PendingHomeworkShareImport): Promise<void> {
    let items = await this.readItems();
    let next: PendingHomeworkShareImport[] = [];
    let replaced = false;
    for (let existing of items) {
      if (existing.token === item.token) {
        next.push(this.clone(item));
        replaced = true;
      } else {
        next.push(existing);
      }
    }
    if (!replaced) next.push(this.clone(item));
    let store = await this.getStore();
    await store.put(ITEMS_KEY, JSON.stringify(next));
    await store.flush();
  }

  async remove(token: string): Promise<void> {
    let items = await this.readItems();
    let next: PendingHomeworkShareImport[] = [];
    for (let item of items) if (item.token !== token) next.push(item);
    let store = await this.getStore();
    await store.put(ITEMS_KEY, JSON.stringify(next));
    await store.flush();
  }
}
