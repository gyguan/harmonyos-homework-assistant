import { describe, expect, it } from '@ohos/hypium';
import { Issue244CaptureSessionFixture } from './fixtures/Issue244CaptureSessionFixture';
import { Issue245ChatReconstructionFixture } from './fixtures/Issue245ChatReconstructionFixture';
import { Issue246HomeworkUnderstandingFixture } from './fixtures/Issue246HomeworkUnderstandingFixture';
import { Issue247FullClosureFixture } from './fixtures/Issue247FullClosureFixture';
import { HomeworkSourceProfileService } from '../main/ets/application/capture/HomeworkSourceProfileService';
import { Subject } from '../main/ets/domain/model/HomeworkModels';

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

    it('source_profile_rejects_cross_subject_teacher_alias_collision', 0, () => {
      let rejected = false;
      try {
        HomeworkSourceProfileService.instance.save({
          id: 'profile-alias-collision-test',
          name: '测试班级',
          groupTitle: '测试班级家长群',
          studentId: 'student-alias-collision-test',
          teacherAliases: [
            { displayName: '王老师', aliases: ['共同老师'], subject: Subject.CHINESE },
            { displayName: '李老师', aliases: ['共同老师'], subject: Subject.MATH }
          ],
          defaultStartMinuteOfDay: 15 * 60,
          enabled: true,
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
          lastUsedAtEpochMs: 0
        });
      } catch {
        rejected = true;
      }
      expect(rejected).assertEqual(true);
    });
  });
}
