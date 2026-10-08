import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ToeicLearningSnapshot, ToeicMockReport, ToeicPart, ToeicPerformance, ToeicQuestionAttempt, ToeicQuestionHistory, ToeicQuestionTime, ToeicSessionDraft, ToeicSkill } from '../domain/ToeicModels';
import { ToeicTrainingService } from '../application/ToeicTrainingService';

const STORE_NAME:string='toeic_coach_progress';
const SNAPSHOT_KEY:string='toeic_learning_snapshot_v1';
const MAX_AVAILABLE_STUDY_DAY:number=21;

export class ToeicProgressStore {
  static readonly instance:ToeicProgressStore=new ToeicProgressStore();
  private store:preferences.Preferences|null=null;
  private snapshot:ToeicLearningSnapshot=new ToeicLearningSnapshot();
  private pendingSave:Promise<void>=Promise.resolve();
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

  attemptCount(questionId:string):number {
    let history=this.findHistory(questionId);
    return history===null?0:history.attemptCount;
  }

  wrongCount(questionId:string):number {
    let history=this.findHistory(questionId);
    return history===null?0:history.wrongCount;
  }

  activeDraft():ToeicSessionDraft|null { return this.snapshot.activeDraft; }

  async saveDraft(draft:ToeicSessionDraft):Promise<void> {
    this.snapshot.activeDraft=draft;
    await this.save();
  }

  async discardDraft():Promise<void> {
    this.snapshot.activeDraft=null;
    await this.save();
  }

  async recordSession(attempts:ToeicQuestionAttempt[], diagnostic:boolean, advanceProgress:boolean=true,
    mockReport:ToeicMockReport|null=null):Promise<void> {
    if (attempts.length===0 && mockReport===null) return;
    let summary=ToeicTrainingService.instance.summarize(attempts);
    this.snapshot.totalAnswered+=attempts.length;
    this.snapshot.totalCorrect+=summary.correctCount;
    this.snapshot.weakSkill=summary.hasWeakSkill?summary.weakSkill:'';
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
    if (mockReport!==null) {
      this.snapshot.mockReports.push(mockReport);
      if (this.snapshot.mockReports.length>10) this.snapshot.mockReports.shift();
    }
    this.snapshot.activeDraft=null;
    await this.save();
  }

  private applyAttempt(attempt:ToeicQuestionAttempt):void {
    let history=this.findHistory(attempt.questionId);
    if (history===null) {
      history=new ToeicQuestionHistory(attempt.questionId);
      this.snapshot.questionHistories.push(history);
    }
    history.attemptCount++;
    if (!attempt.correct) history.wrongCount++;

    if (attempt.correct) this.removeId(this.snapshot.reviewQuestionIds,attempt.questionId);
    else this.addId(this.snapshot.reviewQuestionIds,attempt.questionId);
    if (attempt.performance===ToeicPerformance.SLOW_CORRECT || attempt.performance===ToeicPerformance.SLOW_WRONG) {
      this.addId(this.snapshot.slowQuestionIds,attempt.questionId);
    } else if (attempt.performance===ToeicPerformance.FAST_CORRECT) {
      this.removeId(this.snapshot.slowQuestionIds,attempt.questionId);
    }
  }

  private findHistory(questionId:string):ToeicQuestionHistory|null {
    for (let history of this.snapshot.questionHistories) {
      if (history.questionId===questionId) return history;
    }
    return null;
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
      if (Array.isArray(parsed.questionHistories)) {
        let rawHistories=parsed.questionHistories as Object[];
        for (let rawValue of rawHistories) {
          let raw=rawValue as Record<string,Object>;
          if (typeof raw.questionId!=='string') continue;
          let attemptCount=typeof raw.attemptCount==='number'?raw.attemptCount as number:0;
          let wrongCount=typeof raw.wrongCount==='number'?raw.wrongCount as number:0;
          restored.questionHistories.push(new ToeicQuestionHistory(raw.questionId as string,attemptCount,wrongCount));
        }
      }
      if (restored.schemaVersion<2 && restored.diagnosticCompleted && restored.currentDay===1) {
        restored.currentDay=2;
      }
      if (restored.currentDay>MAX_AVAILABLE_STUDY_DAY) {
        restored.currentDay=MAX_AVAILABLE_STUDY_DAY;
      }
      if (Array.isArray(parsed.mockReports)) {
        for (let record of parsed.mockReports as Object[]) {
          let report=record as Record<string,Object>;
          if (typeof report.day!=='number' || typeof report.completedAtMs!=='number') continue;
          restored.mockReports.push(new ToeicMockReport(
            report.day as number, report.completedAtMs as number,
            Number(report.correctCount), Number(report.answeredCount),
            Number(report.totalCount), Number(report.elapsedSeconds),
            Number(report.part5Correct), Number(report.part6Correct), Number(report.part7Correct)));
        }
      }
      if (parsed.activeDraft!==null && typeof parsed.activeDraft==='object') {
        let raw=parsed.activeDraft as Record<string,Object>;
        if (typeof raw.day==='number' && typeof raw.mode==='string' &&
          Array.isArray(raw.questionIds) && typeof raw.startedAtMs==='number') {
          let attempts:ToeicQuestionAttempt[]=[];
          if (Array.isArray(raw.attempts)) {
            for (let entry of raw.attempts as Object[]) {
              let item=entry as Record<string,Object>;
              if (typeof item.questionId!=='string' || typeof item.selectedIndex!=='number') continue;
              attempts.push(new ToeicQuestionAttempt(
                item.questionId as string,item.part as ToeicPart,item.skill as ToeicSkill,
                item.selectedIndex as number,item.correct===true,
                Number(item.elapsedSeconds),item.performance as ToeicPerformance));
            }
          }
          let times:ToeicQuestionTime[]=[];
          if (Array.isArray(raw.questionTimes)) {
            for (let entry of raw.questionTimes as Object[]) {
              let item=entry as Record<string,Object>;
              if (typeof item.questionId==='string' && typeof item.spentSeconds==='number') {
                times.push(new ToeicQuestionTime(item.questionId as string,item.spentSeconds as number));
              }
            }
          }
          restored.activeDraft=new ToeicSessionDraft(raw.day as number,raw.mode as string,
            raw.questionIds as string[],Math.max(0,Number(raw.currentIndex)||0),attempts,times,
            raw.startedAtMs as number,raw.advancesProgress===true,
            Array.isArray(raw.markedQuestionIds)?raw.markedQuestionIds as string[]:[]);
        }
      }
      restored.schemaVersion=4;
      this.snapshot=restored;
    } catch {
      this.snapshot=new ToeicLearningSnapshot();
    }
  }

  private async save():Promise<void> {
    // Serialize snapshots in call order: an older draft write must never overwrite a submitted report.
    const serialized:string=JSON.stringify(this.snapshot);
    this.pendingSave=this.pendingSave.then(async()=>{
      if (this.store===null) return;
      await this.store.put(SNAPSHOT_KEY,serialized);
      await this.store.flush();
    }).catch(()=>{
      // Keep the in-memory session usable on a failed best-effort local write.
    });
    await this.pendingSave;
  }
}
