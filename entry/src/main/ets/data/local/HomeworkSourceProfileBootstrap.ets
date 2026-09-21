import { HomeworkSourceProfilePersistence } from '../../domain/port/HomeworkSourceProfilePersistence';
import { HomeworkSourceProfileStore } from './HomeworkSourceProfileStore';

export class HomeworkSourceProfileBootstrap {
  static readonly instance: HomeworkSourceProfileBootstrap = new HomeworkSourceProfileBootstrap();
  private constructor() {}

  async initialize(persistence: HomeworkSourceProfilePersistence): Promise<void> {
    await HomeworkSourceProfileStore.instance.initialize(persistence);
  }
}
