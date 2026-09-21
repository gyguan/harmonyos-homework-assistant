import { HomeworkSourceProfile } from '../model/HomeworkSourceProfileModels';

export interface HomeworkSourceProfileRepository {
  get(profileId: string): HomeworkSourceProfile | null;
  getActive(studentId: string): HomeworkSourceProfile | null;
  save(profile: HomeworkSourceProfile): void;
  markUsed(profileId: string): void;
}
