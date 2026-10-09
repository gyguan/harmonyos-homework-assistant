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
    if (questionId==='R-FP3-P5-1528') {
      return new ToeicQuestionTranslation(questionId,'',
        '所有申请人都必须在前台用带照片的证件证明_____身份。',
        ['它自己','他自己','他们自己','我们自己']);
    }
    if (questionId==='R-FP3-FM1-P7-M2-03') {
      return new ToeicQuestionTranslation(questionId,'',
        '这笔订单可以免费使用哪种配送方式？',
        ['到店自取','国际货运','标准配送','加急配送']);
    }
    if (questionId==='R-FP3-FM1-P7-S09-01') {
      return new ToeicQuestionTranslation(questionId,
        '非工作时间门禁通知\n晚上6点后，西侧大堂入口上锁。持有效员工证的员工可使用北侧入口至晚上9点。访客进入前必须致电前台并向安保登记。任何临时访客证离开前都必须归还。',
        '晚上6点后，持有效员工证的员工可以使用哪个入口？',
        ['西侧大堂','北侧入口','装卸区','南侧车库']);
    }
    if (questionId==='R-FP3-FM2-P7-S07-03') {
      return new ToeicQuestionTranslation(questionId,
        '产品安全更新\n[1] Model R 台灯暂停生产，以检查电源适配器。[2] 5月1日之后购买该台灯的顾客应携收据编号联系服务台。[3] 服务台将免费安排回收符合条件的产品。[4] 台灯检查完成后，更换用适配器将在五个工作日内寄出。',
        '句子“为安排上述回收，工作人员将联系顾客商定方便的取件时间。”最适合插入哪里？',
        ['[1]','[2]','[3]','[4]']);
    }
    if (questionId==='R-FP1-P5-1528') {
      return new ToeicQuestionTranslation(questionId,'',
        '每位申请人都必须在前台用带照片的证件证明_____身份。',
        ['它自己','他自己','他们自己（单数 they）','我们自己']);
    }
    if (questionId==='R-FP1-P6-1606') {
      return new ToeicQuestionTranslation(questionId,'',
        '付款_____后，将发送确认邮件。',
        ['接收（主动单数）','被收到','已经收到（主动）','正在接收']);
    }
    if (questionId==='R-FP1-DX-P5-05') {
      return new ToeicQuestionTranslation(questionId,'',
        '更新后的政策上周_____到所有区域办公室。',
        ['发送（原形）','被发送','曾经发送（主动）','正在发送']);
    }
    if (questionId==='R-FP1-M2-P5-010') {
      return new ToeicQuestionTranslation(questionId,'',
        '公司上个月更新了_____隐私政策。',
        ['它','它的','它自己',"it's（it is/has）"]);
    }
    if (questionId==='R-FP1-M2-P6-002') {
      return new ToeicQuestionTranslation(questionId,'',
        '团队负责人在他们_____时会收到打印的检查清单。',
        ['到达（一般现在时）','到达了（过去时）','将到达','到达（名词）']);
    }
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
