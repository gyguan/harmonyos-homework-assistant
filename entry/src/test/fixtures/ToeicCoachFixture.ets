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
    if (!validation.valid || !vocabularyValidation.valid || diagnostic.length!==12 || vocabulary.length<90 || questions.length<54 ||
      sentenceDrills.length!==30 || studyDays.length!==7) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,
        sentenceDrills.length,studyDays.length);
    }
    for (let day=2; day<=7; day++) {
      if (PresetToeicContent.questionsForDay(day).length!==6 ||
        PresetToeicContent.vocabularyForDay(day).length!==15 ||
        PresetToeicContent.sentenceDrillsForDay(day).length!==5) {
        return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length,
          sentenceDrills.length,studyDays.length);
      }
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
