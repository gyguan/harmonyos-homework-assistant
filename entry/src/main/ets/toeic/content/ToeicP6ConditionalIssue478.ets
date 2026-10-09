import { ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill } from '../domain/ToeicModels';

/** #478: Day16 P6 [2] revision. Archived 1610 stays addressable. */
export class ToeicP6ConditionalIssue478 {
  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-FP6-SPRINT-1610",ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.VERB,"Dear Ms. Rivera,\nThank you for reporting the issue with your desk chair. A technician will visit your office tomorrow between 10 A.M. and noon. Please make sure the area around the chair is [1] _____ before the technician arrives. If the chair cannot be repaired on site, we [2] _____ a temporary replacement. The Facilities team expects most repairs to take less than thirty minutes. [3] _____, more complex problems may require the chair to be taken to the workshop. We appreciate [4] _____ cooperation.","Choose the best word for [2].",["provides","provided","will provide","providing"],2,"这是写给 Rivera 女士的本次明日维修承诺，主句用 will provide 表达发生该条件时将提供备用椅。A provides 与主语 we 不一致；B provided 是过去时；D providing 缺少限定谓语。旧题 provide 可表达一般性公司政策，故新版本排除此项。","","will provide a replacement",25,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET,ToeicReviewStatus.PUBLISHED,1)
    ];
  }
}
