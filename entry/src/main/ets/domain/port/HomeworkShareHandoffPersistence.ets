import { PendingHomeworkShareImport } from '../model/HomeworkShareModels';

export interface HomeworkShareHandoffPersistence {
  list(): Promise<PendingHomeworkShareImport[]>;
  find(token: string): Promise<PendingHomeworkShareImport | null>;
  save(item: PendingHomeworkShareImport): Promise<void>;
  remove(token: string): Promise<void>;
}
