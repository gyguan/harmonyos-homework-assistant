import { PresetToeicContent } from '../content/PresetToeicContent';
import { ToeicContentValidator } from '../content/ToeicContentValidator';
import { ToeicExtraReadingContent } from '../content/ToeicExtraReadingContent';
import { ToeicQuestionTranslationCatalog } from '../content/ToeicQuestionTranslationCatalog';
import { ToeicQuestionTranslation } from '../content/ToeicQuestionTranslationModels';
import { ToeicTrainingService } from '../application/ToeicTrainingService';
import { ToeicProgressStore } from '../data/ToeicProgressStore';
import { ToeicPronunciationService, ToeicPronunciationStatus } from '../application/ToeicPronunciationService';
import { ToeicDayTaskProgress, ToeicLearningSnapshot, ToeicMockReport, ToeicPart, ToeicQuestion, ToeicQuestionAttempt, ToeicReviewStatus, ToeicSessionReport, ToeicSessionDraft, ToeicSentenceDrill, ToeicSkill, ToeicStudyDay, ToeicVocabularyItem } from '../domain/ToeicModels';

export class ToeicCoachViewModel {
  snapshot():ToeicLearningSnapshot { return ToeicProgressStore.instance.current(); }
  diagnosticQuestions():ToeicQuestion[] { return ToeicTrainingService.instance.diagnosticQuestions(); }
  standardDiagnosticQuestions():ToeicQuestion[] { return ToeicTrainingService.instance.standardDiagnosticQuestions(); }
  dailyQuestions():ToeicQuestion[] { return ToeicTrainingService.instance.dailyQuestions(this.snapshot()); }
  supplementaryReadingQuestions():ToeicQuestion[] { return PresetToeicContent.supplementaryReadingQuestions(); }
  dailyQuestionsForDay(day:number):ToeicQuestion[] {
    return ToeicTrainingService.instance.studyDayQuestions(this.snapshot(),day);
  }
  attemptCount(questionId:string):number { return ToeicProgressStore.instance.attemptCount(questionId); }
  wrongCount(questionId:string):number { return ToeicProgressStore.instance.wrongCount(questionId); }
  questionTranslation(questionId:string):ToeicQuestionTranslation|null {
    return ToeicQuestionTranslationCatalog.find(questionId);
  }

  createAttempt(question:ToeicQuestion,selectedIndex:number,elapsedSeconds:number):ToeicQuestionAttempt {
    return ToeicTrainingService.instance.createAttempt(question,selectedIndex,elapsedSeconds);
  }
  activeDraft():ToeicSessionDraft|null { return ToeicProgressStore.instance.activeDraft(); }
  questionsForDraft(draft:ToeicSessionDraft):ToeicQuestion[] {
    let source=PresetToeicContent.publishedQuestions();
    let result:ToeicQuestion[]=[];
    for (let id of draft.questionIds) {
      let found:ToeicQuestion|null=null;
      for (let q of source) if (q.id===id) { found=q; break; }
      if (found===null) return [];
      result.push(found);
    }
    return result;
  }
  async saveDraft(draft:ToeicSessionDraft):Promise<void> { await ToeicProgressStore.instance.saveDraft(draft); }
  async discardDraft():Promise<void> { await ToeicProgressStore.instance.discardDraft(); }
  async completeSession(attempts:ToeicQuestionAttempt[],diagnostic:boolean,
    advanceProgress:boolean=true,mockReport:ToeicMockReport|null=null,
    studyDay:number=0):Promise<void> {
    await ToeicProgressStore.instance.recordSession(attempts,diagnostic,advanceProgress,mockReport,studyDay);
  }
  dayTaskProgress(day:number):ToeicDayTaskProgress {
    return ToeicProgressStore.instance.dayTasks(day);
  }
  async completeDayTask(day:number,task:string):Promise<void> {
    await ToeicProgressStore.instance.completeDayTask(day,task);
  }
  recentSessionReports():ToeicSessionReport[] { return this.snapshot().sessionReports.slice(); }
  contentErrors():string[] {
    let all=PresetToeicContent.questions();
    let live:ToeicQuestion[]=[];
    for (let question of all) {
      if (question.reviewStatus===ToeicReviewStatus.PUBLISHED) live.push(question);
    }
    let questionErrors=ToeicContentValidator.validateAll(live).errors;
    let groupErrors=ToeicContentValidator.validateReadingGroups(
      live,PresetToeicContent.publishedReadingGroups()).errors;
    let vocabularyErrors=ToeicContentValidator.validateVocabulary(PresetToeicContent.vocabulary()).errors;
    let sentenceErrors=ToeicContentValidator.validateSentenceDrills(PresetToeicContent.sentenceDrills()).errors;
    let translationErrors=ToeicContentValidator.validateQuestionTranslations(
      PresetToeicContent.questionsRequiringTranslation(),
      ToeicQuestionTranslationCatalog.items()
    ).errors;
    return questionErrors.concat(vocabularyErrors).concat(sentenceErrors).concat(translationErrors).concat(groupErrors);
  }
  vocabularyCount():number { return PresetToeicContent.vocabulary().length; }
  allVocabulary():ToeicVocabularyItem[] { return PresetToeicContent.vocabulary(); }
  todayPlan():ToeicStudyDay { return PresetToeicContent.studyDay(this.snapshot().currentDay); }
  planForDay(day:number):ToeicStudyDay { return PresetToeicContent.studyDay(day); }
  weekOnePlans():ToeicStudyDay[] { return PresetToeicContent.studyDays(); }
  todayVocabulary():ToeicVocabularyItem[] { return PresetToeicContent.vocabularyForDay(this.snapshot().currentDay); }
  vocabularyForDay(day:number):ToeicVocabularyItem[] {
    let planned=PresetToeicContent.vocabularyForDay(day);
    let source=PresetToeicContent.vocabulary();
    let result:ToeicVocabularyItem[]=planned.slice();
    let due=ToeicProgressStore.instance.vocabularyDueIds();
    let reviewCount:number=0;
    for (let id of due) {
      if (reviewCount>=10) break;
      for (let item of source) {
        if (item.id!==id) continue;
        let already=false;
        for (let existing of result) if (existing.id===item.id) { already=true; break; }
        if (!already) { result.unshift(item); reviewCount++; }
        break;
      }
    }
    return result;
  }
  async recordVocabularyRecall(id:string,remembered:boolean):Promise<void> {
    await ToeicProgressStore.instance.recordVocabularyRecall(id,remembered);
  }
  todaySentenceDrills():ToeicSentenceDrill[] { return PresetToeicContent.sentenceDrillsForDay(this.snapshot().currentDay); }
  sentenceDrillsForDay(day:number):ToeicSentenceDrill[] { return PresetToeicContent.sentenceDrillsForDay(day); }
  async pronounce(item:ToeicVocabularyItem):Promise<ToeicPronunciationStatus> {
    return await ToeicPronunciationService.instance.speak(item);
  }

  skillLabel(value:string):string {
    if (value.length===0) return '暂无明显弱项';
    let skill=value as ToeicSkill;
    if (skill===ToeicSkill.WORD_FORM) return '词性判断';
    if (skill===ToeicSkill.VERB) return '动词结构';
    if (skill===ToeicSkill.VOICE) return '主动 / 被动';
    if (skill===ToeicSkill.PREPOSITION) return '介词';
    if (skill===ToeicSkill.CONJUNCTION) return '连词与逻辑';
    if (skill===ToeicSkill.COLLOCATION) return '高频搭配';
    if (skill===ToeicSkill.VOCABULARY) return '高频词汇';
    if (skill===ToeicSkill.CONTEXT) return '上下文理解';
    if (skill===ToeicSkill.PARAPHRASE) return '同义替换';
    if (skill===ToeicSkill.PURPOSE) return '目的题';
    if (skill===ToeicSkill.DETAIL) return '细节定位';
    if (skill===ToeicSkill.INFERENCE) return '推断';
    if (skill===ToeicSkill.CROSS_DOCUMENT) return '跨文档信息';
    return '阅读综合';
  }

  partLabel(part:ToeicPart):string {
    if (part===ToeicPart.PART_5) return 'Part 5';
    if (part===ToeicPart.PART_6) return 'Part 6';
    if (part===ToeicPart.PART_7) return 'Part 7';
    return part;
  }

  accuracyValue(snapshot:ToeicLearningSnapshot):string {
    if (snapshot.totalAnswered<=0) return '--';
    return Math.round(snapshot.totalCorrect*100/snapshot.totalAnswered) + '%';
  }
}
