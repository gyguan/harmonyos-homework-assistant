import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReviewStatus,
  ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Day14 active Part5 content correction.
 * Preserve archived R-M1-P5-022 and its historical answers unchanged.
 * Replaces invented "unanimouslyness" with attested noun "unanimousness".
 */
export class ToeicMockDay14Part5V2Content {
  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion('R-FM1-P5-022',ToeicSection.READING,ToeicPart.PART_5,
        ToeicSkill.WORD_FORM,'',
        'The committee reached a _____ decision after reviewing the data.',
        ['unanimous','unanimously','unanimity','unanimousness'],0,
        'decision 是名词，空格须用形容词 unanimous。B unanimously 是副词；C unanimity 和 D unanimousness 均是名词，不能作此处定语形容词。新版删除原题中非标准构词 unanimouslyness。',
        '',
        'a unanimous decision = a decision everyone supports',
        18,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,1)
    ];
  }
}
