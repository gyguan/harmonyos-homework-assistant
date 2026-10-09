import {
  ToeicDifficulty, ToeicQuestion, ToeicReviewStatus, ToeicSkill
} from '../domain/ToeicModels';
import { ToeicWeekTwoContent } from './ToeicWeekTwoContent';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';

/** Active-only replacements of two ambiguous legacy Part6 blanks.
 * The original paper's IDs, option lists and versions remain immutable.
 */
export class ToeicMockPart6V2RepairContent {
  static day14():ToeicQuestion {
    let archived=ToeicWeekTwoContent.mockQuestions()[32];
    return new ToeicQuestion('R-FM1-P6-033',archived.section,archived.part,
      ToeicSkill.REFERENCE,archived.passage,archived.stem,
      ['they','them','their','themselves'],0,
      'The IT team 是负责断开与重连电脑的团队。连接词 and 后空格是 will reconnect 的主语，只能填主格 they。them 为宾格，their 为形容词性物主代词，themselves 不能独立作此句的主语。旧版 it 也可能指团队，因此新版移除该歧义选项。',
      '',archived.paraphrase,archived.recommendedSeconds,
      ToeicDifficulty.MEDIUM,archived.scoreValue,ToeicReviewStatus.PUBLISHED,1);
  }

  static day19():ToeicQuestion {
    let archived=ToeicWeekThreeContent.mockQuestions()[38];
    return new ToeicQuestion('R-FM2-P6-009',archived.section,archived.part,
      ToeicSkill.VOICE,archived.passage,archived.stem,
      ['were required','was required','is requiring','have been required'],1,
      '改期的原因是讲师当时被要求出席行业会议，使用单数主语的被动结构 was required to attend。were required 与单数 instructor 不一致；is requiring 后不应直接接 to attend；have been required 与单数主语不一致。旧版 needed 与 will need 在缺失通知日期时都可能符合上下文，所以新题采用更明确的被动形式。',
      'was required to attend = had to attend',archived.recommendedSeconds,
      ToeicDifficulty.MEDIUM,archived.scoreValue,ToeicReviewStatus.PUBLISHED,1);
  }
}
