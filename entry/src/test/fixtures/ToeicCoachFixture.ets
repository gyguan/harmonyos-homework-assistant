import { ToeicTrainingService } from '../../main/ets/toeic/application/ToeicTrainingService';
import { PresetToeicContent } from '../../main/ets/toeic/content/PresetToeicContent';
import { ToeicContentValidator } from '../../main/ets/toeic/content/ToeicContentValidator';
import { ToeicLearningSnapshot, ToeicPerformance } from '../../main/ets/toeic/domain/ToeicModels';

export class ToeicCoachFixtureResult {
  passed:boolean;
  questionCount:number;
  diagnosticCount:number;
  vocabularyCount:number;
  sentenceDrillCount:number;
  studyDayCount:number;
  constructor(passed:boolean,questionCount:number,diagnosticCount:number,vocabularyCount:number,
    sentenceDrillCount:number,studyDayCount:number) {
    this.passed=passed; this.questionCount=questionCount; this.diagnosticCount=diagnosticCount;
    this.vocabularyCount=vocabularyCount; this.sentenceDrillCount=sentenceDrillCount; this.studyDayCount=studyDayCount;
  }
}

export class ToeicCoachFixture {
  static run():ToeicCoachFixtureResult {
    let questions=PresetToeicContent.questions();
    let diagnostic=PresetToeicContent.diagnosticQuestions();
    let vocabulary=PresetToeicContent.vocabulary();
    let sentenceDrills=PresetToeicContent.sentenceDrills();
    let studyDays=PresetToeicContent.studyDays();
    let validation=ToeicContentValidator.validateAll(questions);
    let vocabularyValidation=ToeicContentValidator.validateVocabulary(vocabulary);
    let sentenceValidation=ToeicContentValidator.validateSentenceDrills(sentenceDrills);
    if (!validation.valid || !vocabularyValidation.valid || !sentenceValidation.valid ||
      diagnostic.length!==12 || vocabulary.length<90 || questions.length<54 ||
      sentenceDrills.length!==30 || studyDays.length!==7) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,
        sentenceDrills.length,studyDays.length);
    }
    for (let day=2; day<=7; day++) {
      let dayQuestions=PresetToeicContent.questionsForDay(day);
      if (dayQuestions.length!==6 ||
        PresetToeicContent.vocabularyForDay(day).length!==15 ||
        PresetToeicContent.sentenceDrillsForDay(day).length!==5) {
        return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,
          sentenceDrills.length,studyDays.length);
      }
      let stems:string[]=[];
      for (let dayQuestion of dayQuestions) {
        if (stems.indexOf(dayQuestion.stem)>=0) {
          return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,
            sentenceDrills.length,studyDays.length);
        }
        stems.push(dayQuestion.stem);
      }
    }

    let selectedSnapshot=new ToeicLearningSnapshot();
    selectedSnapshot.reviewQuestionIds=[PresetToeicContent.questionsForDay(3)[0].id];
    selectedSnapshot.slowQuestionIds=[PresetToeicContent.questionsForDay(4)[0].id];
    let day2=ToeicTrainingService.instance.studyDayQuestions(selectedSnapshot,2);
    let day3=ToeicTrainingService.instance.studyDayQuestions(selectedSnapshot,3);
    let day2Planned=PresetToeicContent.questionsForDay(2);
    let day3Planned=PresetToeicContent.questionsForDay(3);
    if (day2.length!==day2Planned.length || day3.length!==day3Planned.length) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
    }
    for (let item of day2) {
      let found:boolean=false;
      for (let planned of day2Planned) if (item.id===planned.id) found=true;
      if (!found) {
        return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
      }
    }
    for (let item of day3) {
      let found:boolean=false;
      for (let planned of day3Planned) if (item.id===planned.id) found=true;
      if (!found) {
        return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
      }
    }
    if (day2[0].id===day3[0].id) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
    }

    let q=diagnostic[0];
    let fast=ToeicTrainingService.instance.createAttempt(q,q.correctIndex,1);
    let wrongIndex=q.correctIndex===0?1:0;
    let slow=ToeicTrainingService.instance.createAttempt(q,wrongIndex,q.recommendedSeconds+1);
    if (fast.performance!==ToeicPerformance.FAST_CORRECT || slow.performance!==ToeicPerformance.SLOW_WRONG) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
    }

    let snapshot=new ToeicLearningSnapshot();
    snapshot.reviewQuestionIds=[questions[questions.length-1].id];
    let queue=ToeicTrainingService.instance.dailyQuestions(snapshot,4);
    if (queue.length!==4 || queue[0].id!==snapshot.reviewQuestionIds[0]) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
    }

    let duplicateRiskSnapshot=new ToeicLearningSnapshot();
    duplicateRiskSnapshot.currentDay=2;
    duplicateRiskSnapshot.weakSkill=PresetToeicContent.questionsForDay(2)[0].skill;
    duplicateRiskSnapshot.reviewQuestionIds=[PresetToeicContent.questionsForDay(2)[0].id];
    let daily=ToeicTrainingService.instance.dailyQuestions(duplicateRiskSnapshot,10);
    let dailyIds:string[]=[];
    for (let item of daily) {
      if (dailyIds.indexOf(item.id)>=0) {
        return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
      }
      dailyIds.push(item.id);
    }

    return new ToeicCoachFixtureResult(true,questions.length,diagnostic.length,vocabulary.length,sentenceDrills.length,studyDays.length);
  }
}
