import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ToeicLearningSnapshot, ToeicPerformance, ToeicQuestionAttempt } from '../domain/ToeicModels';
import { ToeicTrainingService } from '../application/ToeicTrainingService';

const STORE_NAME:string='toeic_coach_progress';
const SNAPSHOT_KEY:string='toeic_learning_snapshot_v1';
const MAX_AVAILABLE_STUDY_DAY:number=7;

export class ToeicProgressStore {
  static readonly instance:ToeicProgressStore=new ToeicProgressStore();
  private store:preferences.Preferences|null=null;
  private snapshot:ToeicLearningSnapshot=new ToeicLearningSnapshot();
  private constructor() {}

  async initialize(context:common.UIAbilityContext):Promise<void> {
    try {
      this.store=await preferences.getPreferences(context,STORE_NAME);
      await this.load();
    } catch {
      this.store=null;
      this.snapshot=new ToeicLearningSnapshot();
    }
  }

  current():ToeicLearningSnapshot { return this.snapshot; }

  async recordSession(attempts:ToeicQuestionAttempt[], diagnostic:boolean, advanceProgress:boolean=true):Promise<void> {
    if (attempts.length===0) return;
    let summary=ToeicTrainingService.instance.summarize(attempts);
    this.snapshot.totalAnswered+=attempts.length;
    this.snapshot.totalCorrect+=summary.correctCount;
    this.snapshot.weakSkill=summary.weakSkill;
    if (advanceProgress) {
      if (diagnostic) {
        this.snapshot.diagnosticCompleted=true;
        this.snapshot.currentDay=2;
      } else {
        this.snapshot.completedTrainingSessions++;
        this.snapshot.currentDay=Math.min(MAX_AVAILABLE_STUDY_DAY,this.snapshot.completedTrainingSessions+2);
      }
    }
    for (let attempt of attempts) this.applyAttempt(attempt);
    await this.save();
  }

  private applyAttempt(attempt:ToeicQuestionAttempt):void {
    if (attempt.correct) this.removeId(this.snapshot.reviewQuestionIds,attempt.questionId);
    else this.addId(this.snapshot.reviewQuestionIds,attempt.questionId);
    if (attempt.performance===ToeicPerformance.SLOW_CORRECT || attempt.performance===ToeicPerformance.SLOW_WRONG) {
      this.addId(this.snapshot.slowQuestionIds,attempt.questionId);
    } else if (attempt.performance===ToeicPerformance.FAST_CORRECT) {
      this.removeId(this.snapshot.slowQuestionIds,attempt.questionId);
    }
  }

  private addId(ids:string[], id:string):void { if (ids.indexOf(id)<0) ids.push(id); }
  private removeId(ids:string[], id:string):void { let index=ids.indexOf(id); if (index>=0) ids.splice(index,1); }

  private async load():Promise<void> {
    if (this.store===null) return;
    try {
      let value=await this.store.get(SNAPSHOT_KEY,'');
      if (typeof value!=='string' || value.length===0) return;
      let parsed:Record<string,Object>=JSON.parse(value);
      let restored=new ToeicLearningSnapshot();
      if (typeof parsed.schemaVersion==='number') restored.schemaVersion=parsed.schemaVersion as number;
      if (typeof parsed.diagnosticCompleted==='boolean') restored.diagnosticCompleted=parsed.diagnosticCompleted as boolean;
      if (typeof parsed.currentDay==='number') restored.currentDay=parsed.currentDay as number;
      if (typeof parsed.completedTrainingSessions==='number') restored.completedTrainingSessions=parsed.completedTrainingSessions as number;
      if (typeof parsed.totalAnswered==='number') restored.totalAnswered=parsed.totalAnswered as number;
      if (typeof parsed.totalCorrect==='number') restored.totalCorrect=parsed.totalCorrect as number;
      if (typeof parsed.weakSkill==='string') restored.weakSkill=parsed.weakSkill as string;
      if (Array.isArray(parsed.reviewQuestionIds)) restored.reviewQuestionIds=parsed.reviewQuestionIds as string[];
      if (Array.isArray(parsed.slowQuestionIds)) restored.slowQuestionIds=parsed.slowQuestionIds as string[];
      if (restored.schemaVersion<2 && restored.diagnosticCompleted && restored.currentDay===1) {
        restored.currentDay=2;
      }
      if (restored.currentDay>MAX_AVAILABLE_STUDY_DAY) {
        restored.currentDay=MAX_AVAILABLE_STUDY_DAY;
      }
      restored.schemaVersion=2;
      this.snapshot=restored;
    } catch {
      this.snapshot=new ToeicLearningSnapshot();
    }
  }

  private async save():Promise<void> {
    if (this.store===null) return;
    try {
      await this.store.put(SNAPSHOT_KEY,JSON.stringify(this.snapshot));
      await this.store.flush();
    } catch {
      // Local persistence is best-effort; the active in-memory training session remains usable.
    }
  }
}
