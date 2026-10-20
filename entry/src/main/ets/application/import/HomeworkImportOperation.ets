import { BackendRequestControl } from '../remote/BackendRequestControl';

export enum HomeworkImportPhase {
  PREPARING_TEXT = 'PREPARING_TEXT',
  PREPARING_IMAGE = 'PREPARING_IMAGE',
  WAITING_FOR_AI = 'WAITING_FOR_AI',
  VALIDATING_RESPONSE = 'VALIDATING_RESPONSE',
  LOCAL_DRAFT = 'LOCAL_DRAFT',
  SAVING_DRAFT = 'SAVING_DRAFT',
  COMPLETE = 'COMPLETE'
}

/** Actual client milestones only; never simulates server OCR/review progress or percentages. */
export class HomeworkImportOperation {
  readonly requestControl: BackendRequestControl = new BackendRequestControl();
  private timeoutId: number = -1;
  private readonly onPhase: (phase: HomeworkImportPhase) => void;

  constructor(onPhase: (phase: HomeworkImportPhase) => void, timeoutMs: number = 270000) {
    this.onPhase = onPhase;
    this.timeoutId = setTimeout(() => {
      this.timeoutId = -1;
      this.requestControl.stop('整理等待超时，内容已保留，请稍后重试');
    }, timeoutMs);
  }

  report(phase: HomeworkImportPhase): void {
    this.ensureActive();
    this.onPhase(phase);
  }

  ensureActive(): void { this.requestControl.ensureActive(); }
  isStopped(): boolean { return this.requestControl.isStopped(); }

  cancel(): void {
    this.requestControl.stop('已停止等待，本次结果不会添加到草稿');
    this.finish();
  }

  finish(): void {
    if (this.timeoutId >= 0) { clearTimeout(this.timeoutId); this.timeoutId = -1; }
  }
}
