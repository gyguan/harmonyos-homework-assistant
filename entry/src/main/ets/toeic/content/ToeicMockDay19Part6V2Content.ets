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
      'later. [3] _____\nWe expect the work to be [4] _____ by noon.';
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
          'All scheduled deliveries will be postponed until the following Tuesday.',
          'All staff members should submit their vacation requests by noon.',
          'Customers may browse the showroom while the count is in progress.',
          'Do not move products between shelves during the count.'
        ];
        correctIndex=3;
        explanation='盘点通知要求单独登记损坏物品，接着禁止在盘点中移动货物，避免库存记录与实物位置不符。其余选项引入送货、请假或顾客参观，与仓库盘点操作无关。';
        evidence='Please record damaged items separately so they can be reviewed later.';
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
