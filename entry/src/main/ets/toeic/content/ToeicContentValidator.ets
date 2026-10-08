import { ToeicPart, ToeicQuestion, ToeicReviewStatus, ToeicSection, ToeicSentenceDrill, ToeicVocabularyItem } from '../domain/ToeicModels';
import { ToeicQuestionTranslation } from './ToeicQuestionTranslationModels';

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
      if (item.id.startsWith('V-') && item.id>='V-091') {
        if (item.exampleSentence.trim().length===0) errors.push(item.id + ': example sentence is required');
        if (item.scenario.trim().length===0) errors.push(item.id + ': scenario is required');
        if (item.collocations.length===0 || item.paraphrases.length===0) {
          errors.push(item.id + ': collocations and paraphrases are required');
        }
      }
    }
    return new ToeicContentValidationResult(errors.length===0,errors);
  }

  static validateSentenceDrills(items:ToeicSentenceDrill[]):ToeicContentValidationResult {
    let errors:string[]=[];
    let ids:string[]=[];
    for (let item of items) {
      if (ids.indexOf(item.id)>=0) errors.push(item.id + ': duplicate sentence drill id'); else ids.push(item.id);
      if (item.sentence.trim().length===0) errors.push(item.id + ': sentence is required');
      if (item.translation.trim().length===0) errors.push(item.id + ': translation is required');
      if (item.core.trim().length===0) errors.push(item.id + ': core is required');
      if (item.focus.trim().length===0) errors.push(item.id + ': focus is required');
      if (item.explanation.trim().length===0) errors.push(item.id + ': explanation is required');
    }
    return new ToeicContentValidationResult(errors.length===0,errors);
  }

  static validateQuestionTranslations(questions:ToeicQuestion[],
    translations:ToeicQuestionTranslation[]):ToeicContentValidationResult {
    let errors:string[]=[];
    let ids:string[]=[];
    for (let item of translations) {
      if (ids.indexOf(item.questionId)>=0) errors.push(item.questionId + ': duplicate question translation id');
      else ids.push(item.questionId);
      if (item.stem.trim().length===0) errors.push(item.questionId + ': translated stem is required');
      for (let option of item.options) {
        if (option.trim().length===0) errors.push(item.questionId + ': translated option is required');
      }
    }
    for (let question of questions) {
      let translation:ToeicQuestionTranslation|null=null;
      for (let item of translations) {
        if (item.questionId===question.id) { translation=item; break; }
      }
      if (translation===null) {
        errors.push(question.id + ': Chinese translation is required for Day 1-13 training');
        continue;
      }
      if (question.passage.trim().length>0 && translation.passage.trim().length===0) {
        errors.push(question.id + ': translated passage is required');
      }
      if (translation.options.length!==question.options.length) {
        errors.push(question.id + ': translated option count must match question options');
      }
    }
    return new ToeicContentValidationResult(errors.length===0,errors);
  }

  private static partMatchesSection(section:ToeicSection, part:ToeicPart):boolean {
    if (section===ToeicSection.READING) return part===ToeicPart.PART_5 || part===ToeicPart.PART_6 || part===ToeicPart.PART_7;
    return part===ToeicPart.PART_1 || part===ToeicPart.PART_2 || part===ToeicPart.PART_3 || part===ToeicPart.PART_4;
  }
}
