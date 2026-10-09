import { ToeicQuestion, ToeicReviewStatus } from '../domain/ToeicModels';
import { ToeicMockDay14V2Content } from './ToeicMockDay14V2Content';
import { ToeicMockDay19V2Content } from './ToeicMockDay19V2Content';

/**
 * Replacement Part7 questions for new mock sessions.
 * Historic R-FM1/R-FM2 v1 IDs and all their stored evidence stay immutable.
 * Every replacement has its own ID, published v1 and full group-linked proof.
 */
export class ToeicMockPart7EvidenceRevisionContent {
  private static revised(source:ToeicQuestion[],oldId:string,newId:string,extra:string[]):ToeicQuestion {
    for (let q of source) {
      if (q.id!==oldId) continue;
      let evidence=q.evidence;
      for (let fragment of extra) {
        if (evidence.indexOf(fragment)<0) evidence+=' || '+fragment;
      }
      return new ToeicQuestion(newId,q.section,q.part,q.skill,q.passage,q.stem,
        q.options.slice(),q.correctIndex,q.explanation,evidence,q.paraphrase,
        q.recommendedSeconds,q.difficulty,q.scoreValue,ToeicReviewStatus.PUBLISHED,
        1,q.audioAssetId,q.transcript,q.evidenceStartMs,q.evidenceEndMs,q.groupId);
    }
    throw new Error('Missing published original Part7 question: '+oldId);
  }

  static questions():ToeicQuestion[] {
    let day14=ToeicMockDay14V2Content.questions();
    let day19=ToeicMockDay19V2Content.questions();
    return [
      ToeicMockPart7EvidenceRevisionContent.revised(day14,'R-FM1-P7-M1-01','R-FM1-P7-M1-06',[
        'Please allow 20 minutes to walk from the station.'
      ]),
      ToeicMockPart7EvidenceRevisionContent.revised(day14,'R-FM1-P7-M4-01','R-FM1-P7-M4-06',[
        'It takes about 10 minutes to walk from the bus stop.'
      ]),
      ToeicMockPart7EvidenceRevisionContent.revised(day19,'R-FM2-P7-M1-01','R-FM2-P7-M1-06',[
        'Please arrive at Central Station at least 20 minutes before the meeting'
      ]),
      ToeicMockPart7EvidenceRevisionContent.revised(day19,'R-FM2-P7-M5-03','R-FM2-P7-M5-06',[
        'proficiency with spreadsheet software',
        'advanced spreadsheet certification.',
        'available to start by September 15.',
        'I can begin on September 8 if selected.'
      ])
    ];
  }

  static activeId(originalId:string):string {
    for (let revised of ToeicMockPart7EvidenceRevisionContent.questions()) {
      // Names follow R-FM*-P7-Mx-06, linked to their immutable source below.
      if (revised.id==='R-FM1-P7-M1-06' && originalId==='R-FM1-P7-M1-01') return revised.id;
      if (revised.id==='R-FM1-P7-M4-06' && originalId==='R-FM1-P7-M4-01') return revised.id;
      if (revised.id==='R-FM2-P7-M1-06' && originalId==='R-FM2-P7-M1-01') return revised.id;
      if (revised.id==='R-FM2-P7-M5-06' && originalId==='R-FM2-P7-M5-03') return revised.id;
    }
    return originalId;
  }
}
