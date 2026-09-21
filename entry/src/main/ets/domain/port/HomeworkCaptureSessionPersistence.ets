import { HomeworkCaptureSessionSnapshot } from '../model/CaptureModels';

export interface HomeworkCaptureSessionPersistence {
  load(): Promise<HomeworkCaptureSessionSnapshot | null>;
  save(snapshot: HomeworkCaptureSessionSnapshot): Promise<void>;
}
