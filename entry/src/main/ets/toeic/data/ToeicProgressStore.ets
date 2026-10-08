import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ToeicLearningSnapshot, ToeicMockReport, ToeicPart, ToeicPerformance, ToeicQuestionAttempt, ToeicQuestionHistory, ToeicQuestionTime, ToeicSessionDraft, ToeicSkill, ToeicVocabularyRecall, ToeicDayTaskProgress, ToeicSessionReport, ToeicSkillStat } from '../domain/ToeicModels';
import { ToeicTrainingService } from '../application/ToeicTrainingService';
import { PresetToeicContent } from '../content/PresetToeicContent';

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

  isImportantVocabulary(vocabularyId:string):boolean {
    return this.snapshot.importantVocabularyIds.indexOf(vocabularyId)>=0;
  }

  isUnrememberedVocabulary(vocabularyId:string):boolean {
    return this.snapshot.unrememberedVocabularyIds.indexOf(vocabularyId)>=0;
  }

  async setVocabularyImportant(vocabularyId:string,important:boolean):Promise<void> {
    let ids=this.snapshot.importantVocabularyIds;
    let index=ids.indexOf(vocabularyId);
    if (important && index<0) ids.push(vocabularyId);
    else if (!important && index>=0) ids.splice(index,1);
    else return;
    await this.save();
  }

  vocabularyDueIds(nowMs:number=Date.now()):string[] {
    let ids:string[]=[];
    for (let review of this.snapshot.vocabularyRecalls) {
      if (review.nextDueAtMs<=nowMs) ids.push(review.vocabularyId);
    }
    return ids;
  }

  async recordVocabularyRecall(vocabularyId:string,remembered:boolean):Promise<void> {
    let review:ToeicVocabularyRecall|null=null;
    for (let item of this.snapshot.vocabularyRecalls) {
      if (item.vocabularyId===vocabularyId) { review=item; break; }
    }
    let nowMs=Date.now();
    if (review===null) {
      review=new ToeicVocabularyRecall(vocabularyId,0,0,nowMs,nowMs);
      this.snapshot.vocabularyRecalls.push(review);
    }
    review.totalReviews++;
    review.lastReviewedAtMs=nowMs;
    review.streak=remembered?Math.min(4,review.streak+1):0;
    // A failed recall puts the word at the front of future study lists.
    // A successful recall clears only the automatic weak-word flag, never the user's key-word mark.
    let weakIds=this.snapshot.unrememberedVocabularyIds;
    let weakIndex=weakIds.indexOf(vocabularyId);
    if (!remembered && weakIndex<0) weakIds.push(vocabularyId);
    if (remembered && weakIndex>=0) weakIds.splice(weakIndex,1);
    // Remembered: 1/3/7/14 days. Not remembered: repeat after six hours.
    let intervals:number[]=[0,1,3,7,14];
    let delayMs=remembered?intervals[review.streak]*24*60*60*1000:6*60*60*1000;
    review.nextDueAtMs=nowMs+delayMs;
    await this.save();
  }

  dayTasks(day:number):ToeicDayTaskProgress {
    for (let item of this.snapshot.dayTasks) if (item.day===day) return item;
    return new ToeicDayTaskProgress(day);
  }

  private writableDayTasks(day:number):ToeicDayTaskProgress {
    for (let item of this.snapshot.dayTasks) if (item.day===day) return item;
    let result=new ToeicDayTaskProgress(day);
    this.snapshot.dayTasks.push(result);
    return result;
  }

  private advanceDayIfReady(day:number):void {
    if (!this.snapshot.diagnosticCompleted || day!==this.snapshot.currentDay) return;
    let plan=PresetToeicContent.studyDay(day);
    let progress=this.dayTasks(day);
    if (!progress.trainingCompleted) return;
    if (plan.vocabularyIds.length>0 && !progress.vocabularyCompleted) return;
    if (plan.sentenceDrillIds.length>0 && !progress.sentenceCompleted) return;
    this.snapshot.completedTrainingSessions++;
    this.snapshot.currentDay=Math.min(MAX_AVAILABLE_STUDY_DAY,day+1);
  }

  async completeDayTask(day:number,task:string):Promise<void> {
    if (day<2 || day>MAX_AVAILABLE_STUDY_DAY) return;
    let progress=this.writableDayTasks(day);
    if (task==='vocabulary') progress.vocabularyCompleted=true;
    else if (task==='sentence') progress.sentenceCompleted=true;
    else return;
    this.advanceDayIfReady(day);
    await this.save();
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
    mockReport:ToeicMockReport|null=null,studyDay:number=0):Promise<void> {
    if (attempts.length===0 && mockReport===null) return;
    let summary=ToeicTrainingService.instance.summarize(attempts);
    this.snapshot.totalAnswered+=attempts.length;
    this.snapshot.totalCorrect+=summary.correctCount;
    // The weak skill is recomputed after persisted cumulative statistics are updated.
    if (advanceProgress) {
      if (diagnostic) {
        this.snapshot.diagnosticCompleted=true;
        this.snapshot.currentDay=2;
      } else if (studyDay>=2 && studyDay<=MAX_AVAILABLE_STUDY_DAY) {
        this.writableDayTasks(studyDay).trainingCompleted=true;
        this.advanceDayIfReady(studyDay);
      }
    }
    let report=new ToeicSessionReport(studyDay,Date.now());
    for (let attempt of attempts) {
      this.applyAttempt(attempt);
      report.answered++;
      if (attempt.correct) report.correct++;
      if (attempt.performance===ToeicPerformance.SLOW_CORRECT ||
        attempt.performance===ToeicPerformance.SLOW_WRONG) report.slow++;
      if (attempt.part===ToeicPart.PART_5) {
        report.part5Answered++; report.part5Seconds+=attempt.elapsedSeconds;
        if (attempt.correct) report.part5Correct++;
      } else if (attempt.part===ToeicPart.PART_6) {
        report.part6Answered++; report.part6Seconds+=attempt.elapsedSeconds;
        if (attempt.correct) report.part6Correct++;
      } else if (attempt.part===ToeicPart.PART_7) {
        report.part7Answered++; report.part7Seconds+=attempt.elapsedSeconds;
        if (attempt.correct) report.part7Correct++;
      }
    }
    let ranked=ToeicTrainingService.instance.topWeakSkills(this.snapshot,1);
    this.snapshot.weakSkill=ranked.length>0?ranked[0]:'';
    if (report.answered>0) {
      this.snapshot.sessionReports.push(report);
      if (this.snapshot.sessionReports.length>40) this.snapshot.sessionReports.shift();
    }
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

    let skillStat:ToeicSkillStat|null=null;
    for (let item of this.snapshot.skillStats) {
      if (item.skill===attempt.skill) { skillStat=item; break; }
    }
    if (skillStat===null) {
      skillStat=new ToeicSkillStat(attempt.skill);
      this.snapshot.skillStats.push(skillStat);
    }
    skillStat.answered++;
    if (attempt.correct) skillStat.correct++;
    if (attempt.performance===ToeicPerformance.SLOW_CORRECT ||
      attempt.performance===ToeicPerformance.SLOW_WRONG) skillStat.slow++;

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
      // Old v7 snapshots have neither flag array; keep their progress and recall schedule intact.
      // Ignore malformed IDs and duplicates rather than letting old or corrupt data poison ordering.
      if (Array.isArray(parsed.importantVocabularyIds)) {
        for (let value of parsed.importantVocabularyIds as Object[]) {
          if (typeof value!=='string' || value.length===0 ||
            restored.importantVocabularyIds.indexOf(value as string)>=0) continue;
          restored.importantVocabularyIds.push(value as string);
        }
      }
      if (Array.isArray(parsed.unrememberedVocabularyIds)) {
        for (let value of parsed.unrememberedVocabularyIds as Object[]) {
          if (typeof value!=='string' || value.length===0 ||
            restored.unrememberedVocabularyIds.indexOf(value as string)>=0) continue;
          restored.unrememberedVocabularyIds.push(value as string);
        }
      }
      if (Array.isArray(parsed.vocabularyRecalls)) {
        for (let record of parsed.vocabularyRecalls as Object[]) {
          let recall=record as Record<string,Object>;
          if (typeof recall.vocabularyId!=='string' ||
            typeof recall.nextDueAtMs!=='number') continue;
          restored.vocabularyRecalls.push(new ToeicVocabularyRecall(
            recall.vocabularyId as string,Math.max(0,Number(recall.streak)||0),
            Math.max(0,Number(recall.totalReviews)||0),recall.nextDueAtMs as number,
            Math.max(0,Number(recall.lastReviewedAtMs)||0)));
        }
      }
      if (Array.isArray(parsed.dayTasks)) {
        for (let value of parsed.dayTasks as Object[]) {
          let item=value as Record<string,Object>;
          if (typeof item.day!=='number' || item.day<2 || item.day>MAX_AVAILABLE_STUDY_DAY) continue;
          restored.dayTasks.push(new ToeicDayTaskProgress(item.day as number,
            item.vocabularyCompleted===true,item.sentenceCompleted===true,
            item.trainingCompleted===true));
        }
      }
      if (Array.isArray(parsed.sessionReports)) {
        for (let value of parsed.sessionReports as Object[]) {
          let item=value as Record<string,Object>;
          if (typeof item.day!=='number' || typeof item.completedAtMs!=='number') continue;
          let report=new ToeicSessionReport(item.day as number,item.completedAtMs as number);
          report.answered=Number(item.answered)||0; report.correct=Number(item.correct)||0;
          report.slow=Number(item.slow)||0;
          report.part5Answered=Number(item.part5Answered)||0;
          report.part5Correct=Number(item.part5Correct)||0;
          report.part5Seconds=Number(item.part5Seconds)||0;
          report.part6Answered=Number(item.part6Answered)||0;
          report.part6Correct=Number(item.part6Correct)||0;
          report.part6Seconds=Number(item.part6Seconds)||0;
          report.part7Answered=Number(item.part7Answered)||0;
          report.part7Correct=Number(item.part7Correct)||0;
          report.part7Seconds=Number(item.part7Seconds)||0;
          restored.sessionReports.push(report);
        }
      }
      if (Array.isArray(parsed.skillStats)) {
        for (let value of parsed.skillStats as Object[]) {
          let item=value as Record<string,Object>;
          if (typeof item.skill!=='string') continue;
          restored.skillStats.push(new ToeicSkillStat(item.skill as ToeicSkill,
            Math.max(0,Number(item.answered)||0),
            Math.max(0,Number(item.correct)||0),
            Math.max(0,Number(item.slow)||0)));
        }
      }
      restored.schemaVersion=8;
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
