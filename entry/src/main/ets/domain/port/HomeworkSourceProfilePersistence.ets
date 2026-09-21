import { HomeworkSourceProfileSnapshot } from '../model/HomeworkSourceProfileModels';

export interface HomeworkSourceProfilePersistence {
  load(): Promise<HomeworkSourceProfileSnapshot | null>;
  save(snapshot: HomeworkSourceProfileSnapshot): Promise<void>;
}
