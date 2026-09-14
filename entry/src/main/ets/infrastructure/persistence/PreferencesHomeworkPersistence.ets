import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Assignment, CandidateAssignment, Submission } from '../../domain/model/HomeworkModels';
import { HomeworkSnapshot } from '../../domain/model/PersistenceModels';
import { HomeworkPersistence } from '../../domain/port/HomeworkPersistence';

const STORE_NAME: string = 'homework_assistant_state';
const SNAPSHOT_KEY: string = 'homework_snapshot_v1';

export class PreferencesHomeworkPersistence implements HomeworkPersistence {
  private readonly context: common.UIAbilityContext;
  private store: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store === null) {
      this.store = await preferences.getPreferences(this.context, STORE_NAME);
    }
    return this.store;
  }

  async load(): Promise<HomeworkSnapshot | null> {
    try {
      let store = await this.getStore();
      let value = await store.get(SNAPSHOT_KEY, '');
      if (typeof value !== 'string' || value.length === 0) {
        return null;
      }
      let parsed: Record<string, Object> = JSON.parse(value);
      let snapshot: HomeworkSnapshot = {
        schemaVersion: parsed.schemaVersion as number,
        assignments: parsed.assignments as Assignment[],
        candidates: parsed.candidates as CandidateAssignment[],
        submissions: parsed.submissions as Submission[],
        submissionSequence: parsed.submissionSequence as number
      };
      return snapshot;
    } catch {
      return null;
    }
  }

  async save(snapshot: HomeworkSnapshot): Promise<void> {
    try {
      let store = await this.getStore();
      await store.put(SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch {
      // V0.1 persistence is best-effort. Keep the in-memory state available even if disk persistence fails.
    }
  }
}
