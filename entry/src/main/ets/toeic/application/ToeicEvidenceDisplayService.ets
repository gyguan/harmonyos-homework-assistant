import { ToeicQuestion } from '../domain/ToeicModels';

/**
 * Published evidence-display supplements.
 *
 * Four derived mock Part 7 questions cite genuine source facts but their
 * published v1 evidence fields omit a condition needed for the conclusion.
 * Keep their stored question ID, version, answer and original evidence intact
 * for saved reports. Complete the learner-facing explanation in a shared
 * presentation service used by live questions and both review/report views.
 *
 * Source excerpts must be validated against the current reading groups.
 */
export class ToeicEvidenceSupplement {
  id:string;
  fragments:string[];
  constructor(id:string,fragments:string[]) {
    this.id=id;
    this.fragments=fragments;
  }
}

export class ToeicEvidenceDisplayService {
  static reviewedSupplements():ToeicEvidenceSupplement[] {
    return [
      new ToeicEvidenceSupplement('R-FM1-P7-M1-01',[
        'Please allow 20 minutes to walk from the station.'
      ]),
      new ToeicEvidenceSupplement('R-FM1-P7-M4-01',[
        'It takes about 10 minutes to walk from the bus stop.'
      ]),
      new ToeicEvidenceSupplement('R-FM2-P7-M1-01',[
        'Please arrive at Central Station at least 20 minutes before the meeting'
      ]),
      new ToeicEvidenceSupplement('R-FM2-P7-M5-03',[
        'proficiency with spreadsheet software',
        'advanced spreadsheet certification.',
        'available to start by September 15.',
        'I can begin on September 8 if selected.'
      ])
    ];
  }

  static forQuestion(question:ToeicQuestion):string {
    for (let supplement of ToeicEvidenceDisplayService.reviewedSupplements()) {
      if (supplement.id!==question.id) continue;
      let parts:string[]=[question.evidence];
      for (let fragment of supplement.fragments) {
        if (question.evidence.indexOf(fragment)<0) parts.push(fragment);
      }
      return parts.join(' || ');
    }
    return question.evidence;
  }
}
