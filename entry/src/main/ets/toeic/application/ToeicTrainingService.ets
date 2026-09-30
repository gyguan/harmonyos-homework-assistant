import {
  ToeicDiagnosticSummary, ToeicLearningSnapshot, ToeicPart, ToeicPerformance, ToeicQuestion,
  ToeicQuestionAttempt, ToeicSkill
} from '../domain/ToeicModels';
import { PresetToeicContent } from '../content/PresetToeicContent';

class SkillPenalty {
  skill:ToeicSkill;
  penalty:number;
  constructor(skill:ToeicSkill, penalty:number=0) { this.skill=skill; this.penalty=penalty; }
}

export class ToeicTrainingService {
  static readonly instance:ToeicTrainingService=new ToeicTrainingService();
  private constructor() {}

  diagnosticQuestions():ToeicQuestion[] { return PresetToeicContent.diagnosticQuestions(); }

  dailyQuestions(snapshot:ToeicLearningSnapshot, limit:number=10, studyDay:number=snapshot.currentDay):ToeicQuestion[] {
    let all=PresetToeicContent.publishedQuestions();
    let selected:ToeicQuestion[]=[];
    let recoveryLimit=Math.min(4,limit);

    this.appendByIds(selected,all,snapshot.reviewQuestionIds,recoveryLimit);
    this.appendByIds(selected,all,snapshot.slowQuestionIds,recoveryLimit);

    let weakLimit=Math.min(6,limit);
    let weak=snapshot.weakSkill as ToeicSkill;
    for (let q of all) {
      if (selected.length>=weakLimit) break;
      if (q.skill===weak && !this.containsQuestionId(selected,q.id)) selected.push(q);
    }

    let planned=PresetToeicContent.questionsForDay(studyDay);
    for (let q of planned) {
      if (selected.length>=limit) break;
      if (!this.containsQuestionId(selected,q.id)) selected.push(q);
    }

    let diagnostic=PresetToeicContent.diagnosticQuestions();
    for (let q of all) {
      if (selected.length>=limit) break;
      if (!this.containsQuestionId(selected,q.id) && diagnostic.indexOf(q)<0) selected.push(q);
    }
    return selected;
  }

  studyDayQuestions(snapshot:ToeicLearningSnapshot, studyDay:number):ToeicQuestion[] {
    let planned=PresetToeicContent.questionsForDay(studyDay);
    let selected:ToeicQuestion[]=[];
    this.appendByIds(selected,planned,snapshot.reviewQuestionIds,planned.length);
    this.appendByIds(selected,planned,snapshot.slowQuestionIds,planned.length);

    let weak=snapshot.weakSkill as ToeicSkill;
    for (let question of planned) {
      if (question.skill===weak && !this.containsQuestionId(selected,question.id)) selected.push(question);
    }
    for (let question of planned) {
      if (!this.containsQuestionId(selected,question.id)) selected.push(question);
    }
    return selected;
  }

  classify(question:ToeicQuestion, correct:boolean, elapsedSeconds:number):ToeicPerformance {
    let slow=elapsedSeconds>question.recommendedSeconds;
    if (correct) return slow ? ToeicPerformance.SLOW_CORRECT : ToeicPerformance.FAST_CORRECT;
    return slow ? ToeicPerformance.SLOW_WRONG : ToeicPerformance.FAST_WRONG;
  }

  createAttempt(question:ToeicQuestion, selectedIndex:number, elapsedSeconds:number):ToeicQuestionAttempt {
    let correct=selectedIndex===question.correctIndex;
    return new ToeicQuestionAttempt(question.id,question.part,question.skill,selectedIndex,correct,elapsedSeconds,
      this.classify(question,correct,elapsedSeconds));
  }

  summarize(attempts:ToeicQuestionAttempt[]):ToeicDiagnosticSummary {
    let summary=new ToeicDiagnosticSummary();
    let penalties:SkillPenalty[]=[];
    summary.totalCount=attempts.length;
    for (let a of attempts) {
      if (a.correct) summary.correctCount++;
      let slow=a.performance===ToeicPerformance.SLOW_CORRECT || a.performance===ToeicPerformance.SLOW_WRONG;
      if (slow) summary.slowCount++;
      if (a.part===ToeicPart.PART_5) { summary.part5Total++; if (a.correct) summary.part5Correct++; }
      else if (a.part===ToeicPart.PART_6) { summary.part6Total++; if (a.correct) summary.part6Correct++; }
      else if (a.part===ToeicPart.PART_7) { summary.part7Total++; if (a.correct) summary.part7Correct++; }
      let penalty=a.correct ? 0 : 2;
      if (slow) penalty++;
      this.addPenalty(penalties,a.skill,penalty);
    }
    if (penalties.length>0) {
      let weakest=penalties[0];
      for (let item of penalties) if (item.penalty>weakest.penalty) weakest=item;
      summary.weakSkill=weakest.skill;
    }
    return summary;
  }

  private appendByIds(target:ToeicQuestion[], all:ToeicQuestion[], ids:string[], limit:number):void {
    for (let id of ids) {
      if (target.length>=limit) return;
      for (let q of all) if (q.id===id && !this.containsQuestionId(target,q.id)) { target.push(q); break; }
    }
  }

  private containsQuestionId(items:ToeicQuestion[], questionId:string):boolean {
    for (let item of items) if (item.id===questionId) return true;
    return false;
  }

  private addPenalty(items:SkillPenalty[], skill:ToeicSkill, penalty:number):void {
    for (let item of items) if (item.skill===skill) { item.penalty+=penalty; return; }
    items.push(new SkillPenalty(skill,penalty));
  }
}
