import { HomeworkImportInboxPersistence } from '../../domain/port/HomeworkImportInboxPersistence';
import { HomeworkImportInboxStore } from './HomeworkImportInboxStore';

export class HomeworkImportInboxBootstrap {
  static readonly instance: HomeworkImportInboxBootstrap = new HomeworkImportInboxBootstrap();

  private constructor() {}

  async initialize(persistence: HomeworkImportInboxPersistence): Promise<void> {
    await HomeworkImportInboxStore.instance.initialize(persistence);
  }
}
