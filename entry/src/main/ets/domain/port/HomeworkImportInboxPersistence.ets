import { HomeworkImportInboxSnapshot } from '../model/ImportModels';

export interface HomeworkImportInboxPersistence {
  load(): Promise<HomeworkImportInboxSnapshot | null>;
  save(snapshot: HomeworkImportInboxSnapshot): Promise<void>;
}
