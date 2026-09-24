import { describe, expect, it } from '@ohos/hypium';
import { Issue246HomeworkUnderstandingFixture } from './fixtures/Issue246HomeworkUnderstandingFixture';

export default function homeworkImportLocalTests(): void {
  describe('HomeworkImportDeterministicRules', () => {
    it('issue246_homework_understanding_20_cases', 0, () => {
      let result = Issue246HomeworkUnderstandingFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.caseCount).assertLargerOrEqual(20);
      expect(result.classificationAccuracy).assertEqual(1);
    });
  });
}
