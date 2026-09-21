import { describe, expect, it } from '@ohos/hypium';
import { Issue244CaptureSessionFixture } from './fixtures/Issue244CaptureSessionFixture';
import { Issue245ChatReconstructionFixture } from './fixtures/Issue245ChatReconstructionFixture';
import { Issue246HomeworkUnderstandingFixture } from './fixtures/Issue246HomeworkUnderstandingFixture';
import { Issue247FullClosureFixture } from './fixtures/Issue247FullClosureFixture';

export default function homeworkImportLocalTests(): void {
  describe('HomeworkImportDeterministicRules', () => {
    it('issue244_capture_session_state_machine', 0, async () => {
      let result = await Issue244CaptureSessionFixture.run('student-local-test');
      expect(result.passed).assertEqual(true);
    });

    it('issue245_chat_reconstruction', 0, () => {
      let result = Issue245ChatReconstructionFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.timeBoundaryReached).assertEqual(true);
      expect(result.repeatedMessageEvidenceCount).assertEqual(3);
    });

    it('issue246_homework_understanding_20_cases', 0, () => {
      let result = Issue246HomeworkUnderstandingFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.caseCount).assertLargerOrEqual(20);
      expect(result.classificationAccuracy).assertEqual(1);
    });

    it('issue247_full_closure_and_mixed_group_fail_closed', 0, () => {
      let result = Issue247FullClosureFixture.run();
      expect(result.passed).assertEqual(true);
      expect(result.mixedGroupConflictBlocked).assertEqual(true);
      expect(result.uniqueMessageCount).assertEqual(5);
      expect(result.inWindowMessageCount).assertEqual(4);
    });
  });
}
