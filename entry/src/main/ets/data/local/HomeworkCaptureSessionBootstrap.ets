import { HomeworkCaptureSessionPersistence } from '../../domain/port/HomeworkCaptureSessionPersistence';
import { HomeworkCaptureSessionStore } from './HomeworkCaptureSessionStore';

export class HomeworkCaptureSessionBootstrap {
  static readonly instance: HomeworkCaptureSessionBootstrap = new HomeworkCaptureSessionBootstrap();

  private constructor() {}

  async initialize(persistence: HomeworkCaptureSessionPersistence): Promise<void> {
    await HomeworkCaptureSessionStore.instance.initialize(persistence);
  }
}
