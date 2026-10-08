import { ToeicQuestionTranslation } from './ToeicQuestionTranslationModels';
import { ToeicQuestionTranslationWeekOneCatalog } from './ToeicQuestionTranslationWeekOneCatalog';
import { ToeicQuestionTranslationWeekTwoCatalog } from './ToeicQuestionTranslationWeekTwoCatalog';
import { ToeicQuestionTranslationWeekThreeCatalog } from './ToeicQuestionTranslationWeekThreeCatalog';
import { ToeicQuestionTranslationSupplementaryCatalog } from './ToeicQuestionTranslationSupplementaryCatalog';
import { ToeicQuestionTranslationDay17Catalog } from './ToeicQuestionTranslationDay17Catalog';
import { ToeicQuestionTranslationDay18And20Catalog } from './ToeicQuestionTranslationDay18And20Catalog';

export class ToeicQuestionTranslationCatalog {
  static items():ToeicQuestionTranslation[] {
    return ToeicQuestionTranslationWeekOneCatalog.items()
      .concat(ToeicQuestionTranslationWeekTwoCatalog.items())
      .concat(ToeicQuestionTranslationWeekThreeCatalog.items())
      .concat(ToeicQuestionTranslationSupplementaryCatalog.items())
      .concat(ToeicQuestionTranslationDay17Catalog.items())
      .concat(ToeicQuestionTranslationDay18And20Catalog.items());
  }

  static find(questionId:string):ToeicQuestionTranslation|null {
    let items=ToeicQuestionTranslationCatalog.items();
    for (let item of items) if (item.questionId===questionId) return item;
    return null;
  }
}
