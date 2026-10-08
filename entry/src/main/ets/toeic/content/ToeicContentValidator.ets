import { ToeicPart, ToeicQuestion, ToeicReadingGroup, ToeicReviewStatus, ToeicSection, ToeicSkill, ToeicSentenceDrill, ToeicVocabularyItem } from '../domain/ToeicModels';
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
    if (question.options.length!==4) errors.push(question.id + ': TOEIC item requires exactly four choices');
    let uniqueOptions:string[]=[];
    for (let option of question.options) {
      let normalized=option.trim().toLowerCase();
      if (normalized.length===0) errors.push(question.id + ': empty option');
      if (uniqueOptions.indexOf(normalized)>=0) errors.push(question.id + ': duplicate option');
      uniqueOptions.push(normalized);
    }
    if (question.correctIndex<0 || question.correctIndex>=question.options.length) errors.push(question.id + ': invalid correctIndex');
    if (question.recommendedSeconds<=0) errors.push(question.id + ': recommendedSeconds must be positive');
    if (question.version<=0) errors.push(question.id + ': version must be positive');
    if (!ToeicContentValidator.partMatchesSection(question.section, question.part)) errors.push(question.id + ': part does not match section');
    if (question.reviewStatus===ToeicReviewStatus.PUBLISHED) {
      if (question.explanation.trim().length===0) errors.push(question.id + ': explanation is required');
      if (question.part===ToeicPart.PART_7 && question.evidence.trim().length===0) errors.push(question.id + ': Part 7 evidence is required');
      if (question.part===ToeicPart.PART_5 &&
          question.stem.split('_____').length!==2) {
        errors.push(question.id + ': Part 5 must contain exactly one visible blank');
      }
      if (question.part===ToeicPart.PART_6 && question.passage.indexOf('_____')<0) {
        errors.push(question.id + ': Part 6 passage is missing the completion blank');
      }
      if (question.part===ToeicPart.PART_7 &&
          question.passage.trim().length===0 && question.groupId.trim().length===0) {
        errors.push(question.id + ': Part 7 question must link to reading text');
      }
      if (question.stem.indexOf('题干待')>=0 || question.stem.indexOf('TBD')>=0) {
        errors.push(question.id + ': placeholder question stem is not publishable');
      }
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

  static validateReadingGroups(questions:ToeicQuestion[],
    groups:ToeicReadingGroup[]):ToeicContentValidationResult {
    let errors:string[]=[];
    let groupIds:string[]=[];
    let mappedQuestionIds:string[]=[];
    for (let group of groups) {
      if (group.groupId.trim().length===0 || groupIds.indexOf(group.groupId)>=0) {
        errors.push(group.groupId + ': missing or duplicated group id');
      }
      groupIds.push(group.groupId);
      if (group.passageBlocks.length<2 || group.passageBlocks.length>3) {
        errors.push(group.groupId + ': group requires two or three documents');
      }
      if (group.questionIds.length<2) errors.push(group.groupId + ': insufficient linked questions');
      let answerPositions:number[]=[];
      for (let id of group.questionIds) {
        if (mappedQuestionIds.indexOf(id)>=0) errors.push(id + ': duplicate group membership');
        mappedQuestionIds.push(id);
        let item:ToeicQuestion|null=null;
        for (let question of questions) if (question.id===id) { item=question; break; }
        if (item===null) { errors.push(id + ': missing group question'); continue; }
        if (item.groupId!==group.groupId || item.part!==ToeicPart.PART_7) {
          errors.push(id + ': group id or part mismatch');
        }
        if (item.passage.trim().length>0) errors.push(id + ': group question must not duplicate passage');
        if (item.options.length!==4) errors.push(id + ': Part 7 group item requires four options');
        for (let i=0;i<item.options.length;i++) {
          if (item.options[i].trim().length===0) errors.push(id + ': empty option');
          for (let j=0;j<i;j++) {
            if (item.options[i]===item.options[j]) errors.push(id + ': duplicate option');
          }
        }
        answerPositions.push(item.correctIndex);
        let seenDocuments:number[]=[];
        let evidenceFragments=item.evidence.split(' || ');
        for (let fragment of evidenceFragments) {
          let found=false;
          for (let index=0;index<group.passageBlocks.length;index++) {
            if (group.passageBlocks[index].indexOf(fragment)>=0) {
              found=true;
              if (seenDocuments.indexOf(index)<0) seenDocuments.push(index);
              break;
            }
          }
          if (!found || fragment.trim().length===0) errors.push(id + ': evidence missing in linked documents');
        }
        if (item.skill===ToeicSkill.CROSS_DOCUMENT && seenDocuments.length<2) {
          errors.push(id + ': cross-document question must cite at least two documents');
        }
      }
      // Prevent a group from accidentally testing the same answer position every time.
      for (let index=0;index<4;index++) {
        if (answerPositions.indexOf(index)<0) errors.push(group.groupId + ': answer position not represented ' + index);
      }
    }
    for (let question of questions) {
      if (question.groupId.length>0 && mappedQuestionIds.indexOf(question.id)<0) {
        errors.push(question.id + ': question references an unknown reading group');
      }
    }
    return new ToeicContentValidationResult(errors.length===0,errors);
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
