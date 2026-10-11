import {
  ToeicQuestion, ToeicReadingGroup, ToeicReviewStatus, ToeicSkill
} from '../domain/ToeicModels';
import { ToeicP1FinalQuestionCorrections } from './ToeicP1FinalQuestionCorrections';
import { ToeicMockDay14V2Content } from './ToeicMockDay14V2Content';
import { ToeicMockDay19V2Content } from './ToeicMockDay19V2Content';

/**
 * Issue #519 P3 release-state corrections found by answer-blind review.
 *
 * Historic published IDs remain immutable for saved attempts/reports. New
 * learning sessions route only to these precision revisions.
 */
export class ToeicP3FinalCorrections {
  private static require(source:ToeicQuestion[],id:string):ToeicQuestion {
    for (let question of source) if (question.id===id) return question;
    throw new Error('Missing P3 source question: '+id);
  }

  static questions():ToeicQuestion[] {
    let p1=ToeicP1FinalQuestionCorrections.questions();
    let day14=ToeicMockDay14V2Content.questions();
    let day19=ToeicMockDay19V2Content.questions();

    let pronoun=ToeicP3FinalCorrections.require(p1,'R-FP1-P5-1528');
    let delivery=ToeicP3FinalCorrections.require(day14,'R-FM1-P7-M2-03');
    let badge=ToeicP3FinalCorrections.require(day14,'R-FM1-P7-S09-01');
    let pickup=ToeicP3FinalCorrections.require(day19,'R-FM2-P7-S07-03');

    return [
      new ToeicQuestion('R-FP3-P5-1528',pronoun.section,pronoun.part,ToeicSkill.PRONOUN,
        pronoun.passage,
        'All applicants must identify _____ with a photo ID at reception.',
        ['itself','himself','themselves','ourselves'],2,
        'All applicants 是复数且指人，identify 的宾语与主语回指时使用 themselves。itself 为非人单数，himself 为男性单数，ourselves 为第一人称复数。',
        pronoun.evidence,'identify themselves = prove their identity',
        pronoun.recommendedSeconds,pronoun.difficulty,pronoun.scoreValue,
        ToeicReviewStatus.PUBLISHED,1),

      new ToeicQuestion('R-FP3-FM1-P7-M2-03',delivery.section,delivery.part,delivery.skill,
        delivery.passage,
        'Which delivery option is available at no charge for this order?',
        delivery.options.slice(),2,
        '订单金额为92美元，超过80美元门槛，因此本订单可免费使用标准配送。邮件同时说明顾客不需要加急配送。',
        'Spend $80 or more online and receive free standard delivery. || My cart total is $92.',
        delivery.paraphrase,delivery.recommendedSeconds,delivery.difficulty,delivery.scoreValue,
        ToeicReviewStatus.PUBLISHED,1,delivery.audioAssetId,delivery.transcript,
        delivery.evidenceStartMs,delivery.evidenceEndMs,'FM1-G2'),

      new ToeicQuestion('R-FP3-FM1-P7-S09-01',badge.section,badge.part,badge.skill,
        badge.passage,
        'Which entrance can employees with active staff badges use after 6 P.M.?',
        badge.options.slice(),1,
        '原文明确限定持有效员工证的 employees 晚上6点后可使用 north entrance；不把临时访客证持有人泛化为同一规则。',
        'Employees with active staff badges may use the north entrance until 9 P.M.',
        badge.paraphrase,badge.recommendedSeconds,badge.difficulty,badge.scoreValue,
        ToeicReviewStatus.PUBLISHED,1),

      new ToeicQuestion('R-FP3-FM2-P7-S07-03',pickup.section,pickup.part,ToeicSkill.SENTENCE_LOCATION,
        pickup.passage,
        "Where should this sentence be inserted? 'To schedule that collection, customers will be contacted to arrange a convenient pickup time.'",
        pickup.options.slice(),3,
        'that collection 必须回指前一句 service desk will arrange collection，因此句子只能放在 [4]；放在 [3] 时尚无 collection 先行信息。',
        'The service desk will arrange collection of eligible units at no charge. [4] Replacement adapters will be sent',
        pickup.paraphrase,pickup.recommendedSeconds,pickup.difficulty,pickup.scoreValue,
        ToeicReviewStatus.PUBLISHED,1)
    ];
  }

  static activePart7Id(id:string):string {
    if (id==='R-FM1-P7-M2-03') return 'R-FP3-FM1-P7-M2-03';
    if (id==='R-FM1-P7-S09-01') return 'R-FP3-FM1-P7-S09-01';
    if (id==='R-FM2-P7-S07-03') return 'R-FP3-FM2-P7-S07-03';
    return id;
  }

  static groups():ToeicReadingGroup[] {
    let source=ToeicMockDay14V2Content.groups();
    for (let group of source) {
      if (group.groupId!=='FM1-G2') continue;
      return [new ToeicReadingGroup('FM1-G2',[
        'R-FM1-P7-M2-01','R-FM1-P7-M2-02','R-FP3-FM1-P7-M2-03',
        'R-FM1-P7-M2-04','R-FM1-P7-M2-05'
      ],group.passageBlocks.slice())];
    }
    throw new Error('Missing FM1-G2 for P3 replacement');
  }
}
