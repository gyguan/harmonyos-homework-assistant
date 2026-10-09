import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReviewStatus,
  ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/**
 * #478: two ambiguity-free Part 5 editions for new training sessions.
 * Historical R-P5-VERB-0206 / R-P5-SPRINT-1517 remain addressable for reports.
 */
export class ToeicP5UniqueAnswerIssue478 {
  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion('R-FP5-VERB-0206',ToeicSection.READING,ToeicPart.PART_5,
        ToeicSkill.VERB,'',
        'Employees who _____ the training by Friday will receive a certificate.',
        ['complete','completes','completion','completing'],0,
        'Employees 是复数，who 引导的定语从句缺少谓语；在未来结果条件下使用一般现在时 complete。B completes 是单数谓语；C completion 是名词；D completing 是非谓语形式。旧题 completed 可能引发过去完成培训者的另一种合理解读，故新版排除该项。',
        '',
        'employees who complete the training',16,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,1),
      new ToeicQuestion('R-FP5-SPRINT-1517',ToeicSection.READING,ToeicPart.PART_5,
        ToeicSkill.VERB,'',
        'By the time the client arrives tomorrow, the presentation _____ ready.',
        ['had been','being','will be','have been'],2,
        '明天客户到达之前属于未来时间，主句 will be ready 表示届时准备就绪。A had been 是过去完成时，B being 缺少限定谓语，D have been 既缺单数主语一致性，也不表达该将来时间。新版排除了旧题中一般现在时 is 可能产生的另一种解释。',
        '',
        'will be ready by the time the client arrives tomorrow',15,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,1)
    ];
  }
}
