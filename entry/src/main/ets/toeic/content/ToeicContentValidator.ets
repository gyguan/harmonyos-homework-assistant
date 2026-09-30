import { ToeicPart, ToeicQuestion, ToeicReviewStatus, ToeicSection, ToeicVocabularyItem } from '../domain/ToeicModels';

export class ToeicContentValidationResult {
  valid:boolean; errors:string[];
  constructor(valid:boolean, errors:string[]) { this.valid=valid; this.errors=errors; }
}

export class ToeicContentValidator {
  static validateQuestion(question:ToeicQuestion):ToeicContentValidationResult {
    let errors:string[]=[];
    if (question.id.trim().length===0) errors.push('question id is required');
    if (question.stem.trim().length===0) errors.push(question.id + ': stem is required');
    if (question.options.length<3 || question.options.length>4) errors.push(question.id + ': options must contain 3 or 4 items');
    if (question.correctIndex<0 || question.correctIndex>=question.options.length) errors.push(question.id + ': invalid correctIndex');
    if (question.recommendedSeconds<=0) errors.push(question.id + ': recommendedSeconds must be positive');
    if (question.version<=0) errors.push(question.id + ': version must be positive');
    if (!ToeicContentValidator.partMatchesSection(question.section, question.part)) errors.push(question.id + ': part does not match section');
    if (question.reviewStatus===ToeicReviewStatus.PUBLISHED) {
      if (question.explanation.trim().length===0) errors.push(question.id + ': explanation is required');
      if (question.part===ToeicPart.PART_7 && question.evidence.trim().length===0) errors.push(question.id + ': Part 7 evidence is required');
      if (question.section===ToeicSection.LISTENING) {
        if (question.audioAssetId.trim().length===0) errors.push(question.id + ': listening audioAssetId is required');
        if (question.transcript.trim().length===0) errors.push(question.id + ': listening transcript is required');
      }
    }
    return new ToeicContentValidationResult(errors.length===0, errors);
  }

  static validateAll(questions:ToeicQuestion[]):ToeicContentValidationResult {
    let errors:string[]=[]; let ids:string[]=[];
    for (let q of questions) {
      if (ids.indexOf(q.id)>=0) errors.push(q.id + ': duplicate id'); else ids.push(q.id);
      let r=ToeicContentValidator.validateQuestion(q);
      for (let e of r.errors) errors.push(e);
    }
    return new ToeicContentValidationResult(errors.length===0, errors);
  }

  static validateVocabulary(items:ToeicVocabularyItem[]):ToeicContentValidationResult {
    let errors:string[]=[];
    let ids:string[]=[];
    for (let item of items) {
      if (ids.indexOf(item.id)>=0) errors.push(item.id + ': duplicate vocabulary id'); else ids.push(item.id);
      if (item.word.trim().length===0) errors.push(item.id + ': word is required');
      if (item.meaning.trim().length===0) errors.push(item.id + ': meaning is required');
      if (item.ipa.trim().length===0) errors.push(item.id + ': IPA is required');
      if (item.pronunciationLocale!=='en-US') errors.push(item.id + ': pronunciationLocale must be en-US in current content pack');
      if (item.pronunciationText.trim().length===0) errors.push(item.id + ': pronunciationText is required');
    }
    return new ToeicContentValidationResult(errors.length===0,errors);
  }

  private static partMatchesSection(section:ToeicSection, part:ToeicPart):boolean {
    if (section===ToeicSection.READING) return part===ToeicPart.PART_5 || part===ToeicPart.PART_6 || part===ToeicPart.PART_7;
    return part===ToeicPart.PART_1 || part===ToeicPart.PART_2 || part===ToeicPart.PART_3 || part===ToeicPart.PART_4;
  }
}
