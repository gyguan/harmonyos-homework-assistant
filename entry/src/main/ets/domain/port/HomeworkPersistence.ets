import { HomeworkSnapshot } from '../model/PersistenceModels';

export interface HomeworkPersistence {
  load(): Promise<HomeworkSnapshot | null>;
  save(snapshot: HomeworkSnapshot): Promise<void>;
}
