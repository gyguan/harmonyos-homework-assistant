import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReviewStatus,
  ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Day19 active-mock P5 replacement. Do not mutate the archived
 * R-M2-P5-007: simple present "visits" can describe a scheduled future trip.
 * Its historical answers and v1 reports must stay reproducible.
 */
export class ToeicMockDay19Part5V2Content {
  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion('R-FM2-P5-007',ToeicSection.READING,ToeicPart.PART_5,
        ToeicSkill.VERB,'',
        'Mr. Singh _____ the regional office next Monday.',
        ['visit','visited','will visit','has visited'],2,
        'next Monday 表示尚未发生的下周行程。will visit 是语法与时态均适合的唯一选项：A visit 缺少第三人称单数 -s；B visited 表示过去；D has visited 表示完成时，不能用 next Monday 指未来到访。旧题 visits 可表达已安排的将来行程，故在新版题中改为 visit 排除双答案。',
        '',
        'will visit next Monday = is going to visit next Monday',
        10,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,1)
    ];
  }
}
