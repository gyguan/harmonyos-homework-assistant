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
    let weakSkills=this.topWeakSkills(snapshot,3);
    for (let skill of weakSkills) {
      for (let q of all) {
        if (selected.length>=weakLimit) break;
        if (q.skill===skill && !this.containsQuestionId(selected,q.id)) selected.push(q);
      }
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
    if (PresetToeicContent.isWeaknessDay(studyDay)) {
      return this.weaknessDayQuestions(snapshot,18)
        .concat(PresetToeicContent.supplementaryReadingQuestionsForDay(studyDay));
    }
    if (PresetToeicContent.isHighErrorReviewDay(studyDay)) {
      return this.highErrorReviewQuestions(snapshot,20)
        .concat(PresetToeicContent.supplementaryReadingQuestionsForDay(studyDay));
    }
    let planned=PresetToeicContent.questionsForDay(studyDay);
    if (PresetToeicContent.isMockDay(studyDay)) return planned;
    // Preserve both the existing multi-document passages and newly published extra groups
    // as contiguous sets; question-wise weak-skill sorting would fragment the shared text.
    if (PresetToeicContent.supplementaryGroupIdsForDay(studyDay).length>0) return planned;
    let selected:ToeicQuestion[]=[];
    this.appendByIds(selected,planned,snapshot.reviewQuestionIds,planned.length);
    this.appendByIds(selected,planned,snapshot.slowQuestionIds,planned.length);

    let ranked=this.topWeakSkills(snapshot,3);
    for (let skill of ranked) {
      for (let question of planned) {
        if (question.skill===skill && !this.containsQuestionId(selected,question.id)) selected.push(question);
      }
    }
    for (let question of planned) {
      if (!this.containsQuestionId(selected,question.id)) selected.push(question);
    }
    return selected;
  }

  private weaknessDayQuestions(snapshot:ToeicLearningSnapshot,limit:number):ToeicQuestion[] {
    let source=PresetToeicContent.questionsThroughDay(17);
    let selected:ToeicQuestion[]=[];
    this.appendByIds(selected,source,snapshot.reviewQuestionIds,Math.min(6,limit));
    this.appendByIds(selected,source,snapshot.slowQuestionIds,Math.min(10,limit));

    let ranked=this.topWeakSkills(snapshot,3);
    for (let skill of ranked) {
      for (let question of source) {
        if (selected.length>=Math.min(14,limit)) break;
        if (question.skill===skill && !this.containsQuestionId(selected,question.id)) selected.push(question);
      }
    }
    for (let question of source) {
      if (selected.length>=limit) break;
      if (!this.containsQuestionId(selected,question.id)) selected.push(question);
    }
    return selected;
  }

  private highErrorReviewQuestions(snapshot:ToeicLearningSnapshot,limit:number):ToeicQuestion[] {
    let source=PresetToeicContent.questionsThroughDay(19);
    let selected:ToeicQuestion[]=[];
    let histories=snapshot.questionHistories.slice();
    histories.sort((a,b)=>{
      if (a.wrongCount!==b.wrongCount) return b.wrongCount-a.wrongCount;
      return b.attemptCount-a.attemptCount;
    });
    for (let history of histories) {
      if (selected.length>=limit) break;
      if (history.wrongCount<2) break;
      this.appendByIds(selected,source,[history.questionId],limit);
    }

    this.appendByIds(selected,source,snapshot.reviewQuestionIds,Math.min(14,limit));
    this.appendByIds(selected,source,snapshot.slowQuestionIds,Math.min(17,limit));

    let ranked=this.topWeakSkills(snapshot,3);
    for (let skill of ranked) {
      for (let question of source) {
        if (selected.length>=limit) break;
        if (question.skill===skill && !this.containsQuestionId(selected,question.id)) selected.push(question);
      }
    }
    for (let question of source) {
      if (selected.length>=limit) break;
      if (!this.containsQuestionId(selected,question.id)) selected.push(question);
    }
    return selected;
  }

  topWeakSkills(snapshot:ToeicLearningSnapshot,limit:number=3):ToeicSkill[] {
    let stats=snapshot.skillStats.slice();
    stats.sort((a,b)=>{
      let penaltyA=a.answered>0?(2*(a.answered-a.correct)+a.slow)/a.answered:0;
      let penaltyB=b.answered>0?(2*(b.answered-b.correct)+b.slow)/b.answered:0;
      if (penaltyA!==penaltyB) return penaltyB-penaltyA;
      return b.answered-a.answered;
    });
    let skills:ToeicSkill[]=[];
    for (let item of stats) {
      if (skills.length>=limit) break;
      if (item.answered<=0 || (item.answered===item.correct && item.slow===0)) continue;
      skills.push(item.skill);
    }
    if (skills.length===0 && snapshot.skillStats.length===0 && snapshot.weakSkill.length>0) {
      skills.push(snapshot.weakSkill as ToeicSkill);
    }
    return skills;
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
    // Do not invent a weak skill when every answer was both correct and within time.
    if (penalties.length>0) {
      let weakest=penalties[0];
      for (let item of penalties) if (item.penalty>weakest.penalty) weakest=item;
      if (weakest.penalty>0) {
        summary.weakSkill=weakest.skill;
        summary.hasWeakSkill=true;
      }
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
