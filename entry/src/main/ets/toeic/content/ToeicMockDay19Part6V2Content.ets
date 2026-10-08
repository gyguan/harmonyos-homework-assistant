import {
  ToeicDifficulty, ToeicQuestion, ToeicReviewStatus, ToeicSkill
} from '../domain/ToeicModels';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';

/**
 * A versioned Day19 Part6 inventory letter with an entire-sentence blank.
 * Keep every original R-M2-P6-* question immutable so saved v1/v2 drafts,
 * submitted reports and historic question versions remain resolvable.
 * New sessions replace only the first four Part6 IDs with these four IDs.
 */
export class ToeicMockDay19Part6V2Content {
  static questions():ToeicQuestion[] {
    let oldPaper=ToeicWeekThreeContent.mockQuestions();
    let passage='Dear Team,\nThe annual inventory count will begin at 7 A.M. Saturday. '+
      '[1] _____ the warehouse is normally closed on weekends, only employees assigned '+
      'to the count should enter the building. Team leaders will receive printed checklists '+
      'when they [2] _____. Please record damaged items separately so they can be reviewed '+
      "later. Each product's assigned shelf must match its location on the checklist. "+
      '[3] _____\nWe expect the work to be [4] _____ by noon.';
    let items:ToeicQuestion[]=[];
    for (let i=0;i<4;i++) {
      let original=oldPaper[30+i];
      let id='R-FM2-P6-'+String(i+1).padStart(3,'0');
      let skill=original.skill;
      let stem=original.stem;
      let options=original.options.slice();
      let correctIndex=original.correctIndex;
      let explanation=original.explanation;
      let evidence=original.evidence;
      let difficulty=original.difficulty;
      if (i===2) {
        // Only option D fits the inventory-control instructions and supplies
        // a full grammatical sentence; the other three introduce alien topics.
        skill=ToeicSkill.SENTENCE_INSERTION;
        stem='Which sentence best completes blank [3] in the inventory notice?';
        options=[
          'Staff may change shelf location codes whenever they find a better layout.',
          'Team leaders should replace the inventory checklists with sales brochures.',
          'Employees who are not assigned to the count may enter the warehouse to help.',
          'Do not move products between shelves during the count.'
        ];
        correctIndex=3;
        explanation='原文要求每件商品的货架位置与清单上的位置一致，因此盘点期间不得随意移动货物。A允许变更货架编码，与固定位置要求冲突；B以销售手册取代盘点清单，违背已安排发放盘点清单的要求；C允许未获指派的人员入仓，违背仅限盘点人员进入的明确限制。D是唯一符合操作要求的完整句子。';
        evidence="Each product's assigned shelf must match its location on the checklist.";
        difficulty=ToeicDifficulty.MEDIUM;
      }
      items.push(new ToeicQuestion(id,original.section,original.part,skill,passage,
        stem,options,correctIndex,explanation,evidence,original.paraphrase,
        original.recommendedSeconds,difficulty,original.scoreValue,
        ToeicReviewStatus.PUBLISHED,1));
    }
    return items;
  }
}
