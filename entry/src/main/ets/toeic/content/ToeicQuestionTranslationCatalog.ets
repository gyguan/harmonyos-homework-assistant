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
    if (questionId==='R-FP6-SPRINT-1610') {
      return new ToeicQuestionTranslation(questionId,'',
        '如果椅子无法现场修复，我们_____提供临时替换椅。',
        ['提供（单数谓语）','曾提供（过去式）','将提供（将来时）','提供（非谓语）']);
    }
    // Revised active questions keep translated feedback without altering the
    // fixed 221-row historical translation catalog or old mock reports.
    if (questionId==='R-FP5-VERB-0206') {
      return new ToeicQuestionTranslation(questionId,'',
        '在周五前_____培训的员工将获得证书。',
        ['完成（复数主语谓语）','完成（第三人称单数）','完成（名词）','正在完成（非谓语）']);
    }
    if (questionId==='R-FP5-SPRINT-1517') {
      return new ToeicQuestionTranslation(questionId,'',
        '到明天客户到达时，演示文稿_____准备就绪。',
        ['过去已经是','正在是（非谓语）','将会是（将来时）','已经是（复数完成时）']);
    }
    let items=ToeicQuestionTranslationCatalog.items();
    for (let item of items) if (item.questionId===questionId) return item;
    return null;
  }
}
