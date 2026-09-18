import { HomeworkStore } from '../HomeworkStore';
import { HomeworkPersistence } from '../../domain/port/HomeworkPersistence';

export class HomeworkLocalBootstrap {
  static readonly instance: HomeworkLocalBootstrap = new HomeworkLocalBootstrap();

  private constructor() {}

  async initialize(persistence: HomeworkPersistence): Promise<void> {
    await HomeworkStore.instance.initialize(persistence);
  }
}
