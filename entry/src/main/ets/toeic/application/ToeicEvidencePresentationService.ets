/**
 * Complete learner-facing proof for four already-published multi-document questions.
 *
 * The answer, question ID, stored evidence, and published version remain immutable
 * for mock history replay. Presenting omitted clauses is an explanatory display
 * correction, not a change to scoring or the saved attempt contract.
 */
export class ToeicEvidencePresentationService {
  static fullEvidence(questionId:string, savedEvidence:string):string {
    if (questionId==='R-FM1-P7-M1-01') {
      return savedEvidence+' || Please allow 20 minutes to walk from the station.';
    }
    if (questionId==='R-FM1-P7-M4-01') {
      return savedEvidence+' || It takes about 10 minutes to walk from the bus stop.';
    }
    if (questionId==='R-FM2-P7-M1-01') {
      return savedEvidence+' || Please arrive at Central Station at least 20 minutes before the meeting so we can walk together.';
    }
    if (questionId==='R-FM2-P7-M5-03') {
      return savedEvidence+' || proficiency with spreadsheet software || advanced spreadsheet certification. || available to start by September 15. || I can begin on September 8 if selected.';
    }
    return savedEvidence;
  }
}
