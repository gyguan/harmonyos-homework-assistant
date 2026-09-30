import { ToeicTrainingService } from '../../main/ets/toeic/application/ToeicTrainingService';
import { PresetToeicContent } from '../../main/ets/toeic/content/PresetToeicContent';
import { ToeicContentValidator } from '../../main/ets/toeic/content/ToeicContentValidator';
import { ToeicLearningSnapshot, ToeicPerformance } from '../../main/ets/toeic/domain/ToeicModels';

export class ToeicCoachFixtureResult {
  passed:boolean;
  questionCount:number;
  diagnosticCount:number;
  vocabularyCount:number;
  constructor(passed:boolean,questionCount:number,diagnosticCount:number,vocabularyCount:number) {
    this.passed=passed; this.questionCount=questionCount; this.diagnosticCount=diagnosticCount; this.vocabularyCount=vocabularyCount;
  }
}

export class ToeicCoachFixture {
  static run():ToeicCoachFixtureResult {
    let questions=PresetToeicContent.questions();
    let diagnostic=PresetToeicContent.diagnosticQuestions();
    let vocabulary=PresetToeicContent.vocabulary();
    let validation=ToeicContentValidator.validateAll(questions);
    if (!validation.valid || diagnostic.length!==12 || vocabulary.length<30 || questions.length<18) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length);
    }

    let q=diagnostic[0];
    let fast=ToeicTrainingService.instance.createAttempt(q,q.correctIndex,1);
    let wrongIndex=q.correctIndex===0?1:0;
    let slow=ToeicTrainingService.instance.createAttempt(q,wrongIndex,q.recommendedSeconds+1);
    if (fast.performance!==ToeicPerformance.FAST_CORRECT || slow.performance!==ToeicPerformance.SLOW_WRONG) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length);
    }

    let snapshot=new ToeicLearningSnapshot();
    snapshot.reviewQuestionIds=[questions[questions.length-1].id];
    let queue=ToeicTrainingService.instance.dailyQuestions(snapshot,4);
    if (queue.length!==4 || queue[0].id!==snapshot.reviewQuestionIds[0]) {
      return new ToeicCoachFixtureResult(false,questions.length,diagnostic.length,vocabulary.length);
    }
    return new ToeicCoachFixtureResult(true,questions.length,diagnostic.length,vocabulary.length);
  }
}
