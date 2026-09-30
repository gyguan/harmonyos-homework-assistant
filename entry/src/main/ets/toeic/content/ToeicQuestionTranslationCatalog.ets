import { ToeicQuestionTranslation } from './ToeicQuestionTranslationModels';
import { ToeicQuestionTranslationWeekOneCatalog } from './ToeicQuestionTranslationWeekOneCatalog';
import { ToeicQuestionTranslationWeekTwoCatalog } from './ToeicQuestionTranslationWeekTwoCatalog';

export class ToeicQuestionTranslationCatalog {
  static items():ToeicQuestionTranslation[] {
    return ToeicQuestionTranslationWeekOneCatalog.items().concat(ToeicQuestionTranslationWeekTwoCatalog.items());
  }

  static find(questionId:string):ToeicQuestionTranslation|null {
    let items=ToeicQuestionTranslationCatalog.items();
    for (let item of items) if (item.questionId===questionId) return item;
    return null;
  }
}
