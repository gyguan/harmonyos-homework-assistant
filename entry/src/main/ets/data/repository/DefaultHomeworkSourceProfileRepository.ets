import { HomeworkSourceProfileStore } from '../local/HomeworkSourceProfileStore';
import { HomeworkSourceProfile } from '../../domain/model/HomeworkSourceProfileModels';
import { HomeworkSourceProfileRepository } from '../../domain/port/HomeworkSourceProfileRepository';

export class DefaultHomeworkSourceProfileRepository implements HomeworkSourceProfileRepository {
  static readonly instance: DefaultHomeworkSourceProfileRepository =
    new DefaultHomeworkSourceProfileRepository();

  private readonly store: HomeworkSourceProfileStore = HomeworkSourceProfileStore.instance;

  private constructor() {}

  get(profileId: string): HomeworkSourceProfile | null {
    return this.store.get(profileId);
  }

  getActive(studentId: string): HomeworkSourceProfile | null {
    return this.store.getActive(studentId);
  }

  save(profile: HomeworkSourceProfile): void {
    this.store.save(profile);
  }

  markUsed(profileId: string): void {
    this.store.markUsed(profileId);
  }
}
