import { describe, expect, it } from '@ohos/hypium';
import { Issue246HomeworkUnderstandingFixture } from './fixtures/Issue246HomeworkUnderstandingFixture';
import { ToeicCoachFixture } from './fixtures/ToeicCoachFixture';

export default function homeworkImportLocalTests(): void {
  describe('HomeworkImportDeterministicRules', () => {
    it('issue246_homework_understanding_20_cases', 0, () => {
      let result = Issue246HomeworkUnderstandingFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.caseCount).assertLargerOrEqual(20);
      expect(result.classificationAccuracy).assertEqual(1);
    });
  });

  describe('ToeicCoachContentRules', () => {
    it('issue407_toeic_content_and_training_rules', 0, () => {
      let result = ToeicCoachFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.questionCount).assertLargerOrEqual(54);
      expect(result.diagnosticCount).assertEqual(12);
      expect(result.vocabularyCount).assertLargerOrEqual(90);
      expect(result.sentenceDrillCount).assertEqual(30);
      expect(result.studyDayCount).assertEqual(7);
    });
  });
}
