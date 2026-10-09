import {
  ToeicDifficulty, ToeicQuestion, ToeicReviewStatus, ToeicSkill
} from '../domain/ToeicModels';
import { ToeicMockDay19Part6V2Content } from './ToeicMockDay19Part6V2Content';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';

/**
 * Two active-only replacements for adjective/participle double answers.
 * Never mutate original FM2-P6-004 or the archived M2-P6-008: prior reports
 * and drafts must keep resolving the exact original ID and version.
 */
export class ToeicMockDay19Part6CompletionContent {
  static inventory():ToeicQuestion {
    let original=ToeicMockDay19Part6V2Content.questions()[3];
    return new ToeicQuestion('R-FM2-P6-017',original.section,original.part,
      ToeicSkill.VOICE,original.passage,original.stem,
      ['completes','completed','completing','completion'],1,
      'We expect the work to be completed by noon 中 to be completed 为被动完成。A completes 是第三人称单数谓语，不能跟在 to be 后；C completing 无法在此构成受事 work 的被动语态；D completion 是名词。旧题的 complete 是合法形容词表语，故在新版删除以避免双答案。',
      '', 'be completed by noon = finished by noon',
      original.recommendedSeconds,ToeicDifficulty.EASY,original.scoreValue,
      ToeicReviewStatus.PUBLISHED,1);
  }

  static library():ToeicQuestion {
    let original=ToeicWeekThreeContent.mockQuestions()[37];
    return new ToeicQuestion('R-FM2-P6-018',original.section,original.part,
      ToeicSkill.VOICE,original.passage,original.stem,
      ['completion','completed','completing','completeness'],1,
      'while these improvements are completed 使用被动过去分词表示改进施工正在完成或获完成的过程。A completion、D completeness 为名词，不能直接充当此处 are 后的被动谓语；C completing 是主动现在分词。原题 complete 也可以作为形容词表语，故新版不再使用该干扰项。',
      '', 'improvements are completed = improvements are finished',
      original.recommendedSeconds,ToeicDifficulty.EASY,original.scoreValue,
      ToeicReviewStatus.PUBLISHED,1);
  }
}
