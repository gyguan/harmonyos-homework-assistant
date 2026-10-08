import { ToeicQuestionTranslation } from './ToeicQuestionTranslationModels';

/** Existing published Day 12/13 multi-document groups; translations are study aids only. */
export class ToeicQuestionTranslationSupplementaryCatalog {
  static items():ToeicQuestionTranslation[] {
    let venuePassage:string="文档1——海港会议中心预订指南\n枫木厅最多可容纳55名参加者，雪松厅最多可容纳90名。从枫木厅更换到雪松厅需另付160美元租金。更换场地的请求最迟应于9月12日送达场地协调员。最终餐饮人数须于活动前五个工作日提供。\n\n文档2——9月10日的邮件\n收件人：海港会议中心\n主题：10月7日研讨会——预订编号HC-204\n我们最初为48人预订枫木厅，现在报名人数增至62人，希望改用雪松厅。请保持研讨会日期不变。最终午餐人数我们将另行确认。\n——培训团队 Min Seo";
    let deliveryPassage:string="文档1——办公设备订单PO-318\n24台显示器的标准配送计划不迟于10月16日送达。加急配送需另付80美元，并保证不迟于10月13日送达。加急升级必须在10月10日下午4点前提出。\n\n文档2——10月9日的内部消息\n收件人：采购部\n设施团队将于10月15日开始布置培训室。我们需要在开工前收到全部24台新显示器。如果普通配送无法满足该期限，请安排更快的配送方式，但增加运费前必须先获得采购批准。\n——运营部 Elena";
    let travelPassage:string="文档1——差旅费用规定\n经批准的商务出差，员工每晚可申请不超过145美元（税前）的酒店住宿费。酒店和出租车费用均须提供逐项明细收据。报销申请应在行程结束后的30个自然日内提交。\n\n文档2——出差记录\n项目工程师 Adrian Lee 于11月4日至6日前往波特兰参加供应商会议。所附酒店明细收据显示住宿两晚，每晚税前138美元。出租车费用汇总金额为48美元，但仅附银行卡对账单。\n\n文档3——11月11日财务补充说明\n收件人：Adrian Lee\n我们已收到你这次波特兰差旅的报销草稿。酒店收据齐全。请在提交申请前补上传出租车逐项明细收据；仅凭银行卡对账单不符合单据规定。无需进行其他修改。";
    let filterPassage:string="文档1——供应协议SA-218\n仓库订购了40个替换用空气滤芯，单价12美元。全订单仅收取一次30美元运费，即使分批配送也是如此。10月10日后仍未交付的货物可获得贷项通知单；之前已收货的部分不需要修改发票。\n\n文档2——10月3日仓库收货记录\n订单SA-218：已收到并清点38个滤芯。随货发票列出了全部40个滤芯的约定单价及一次性运费。收货经理当天下午向供应商报告了缺少的两件货品。\n\n文档3——10月5日供应商邮件\n我们核查包装记录后确认，首箱只发出38个滤芯。剩余两个计划于10月9日发货，使用保证次日送达的运输方式，于10月10日到货。我们不会另收运费。如果余货于10月10日前到达，原发票可以保持不变。";
    return [
      new ToeicQuestionTranslation("R-P7-VENUE-01",venuePassage,
        "Min Seo 为什么给会议中心写邮件？",["取消研讨会","更改研讨会日期","申请更大的房间","减少餐饮订单"]),
      new ToeicQuestionTranslation("R-P7-VENUE-02",venuePassage,
        "为什么原先预订的房间不再适用？",["报名人数超过房间容纳上限","该房间无法提供餐饮","场馆在10月7日关闭","协调员提高了租金"]),
      new ToeicQuestionTranslation("R-P7-VENUE-03",venuePassage,
        "这次换房间需要额外支付多少租金？",["55美元","90美元","62美元","160美元"]),
      new ToeicQuestionTranslation("R-P7-VENUE-04",venuePassage,
        "培训团队稍后会提供什么信息？",["预订编号","最终午餐人数","场馆位置","研讨会日期"]),
      new ToeicQuestionTranslation("R-P7-VENUE-05",venuePassage,
        "更换房间的请求是否在规定截止日期前发出？",["否，邮件发于9月12日之后","否，场馆不允许更换房间","是，邮件于9月10日发出","是，因为研讨会在11月举行"]),
      new ToeicQuestionTranslation("R-P7-DELIVERY-01",deliveryPassage,
        "依据列出的配送承诺，哪种方式能保证显示器在10月15日布置培训室之前送达？",["标准配送","加急配送","两种方式都可以","两种方式都不行"]),
      new ToeicQuestionTranslation("R-P7-DELIVERY-02",deliveryPassage,
        "增加配送费用之前，采购部门必须取得什么？",["新的订单编号","安全检查","已签字的送货单","采购审批"]),
      new ToeicQuestionTranslation("R-P7-DELIVERY-03",deliveryPassage,
        "加急配送会使订单额外增加多少费用？",["80美元","24美元","13美元","16美元"]),
      new ToeicQuestionTranslation("R-P7-DELIVERY-04",deliveryPassage,
        "最迟应在什么时候申请加急配送？",["10月9日下午4点","10月15日中午","10月10日下午4点","10月16日下午4点"]),
      new ToeicQuestionTranslation("R-P7-DELIVERY-05",deliveryPassage,
        "为什么运营部门要求显示器提前送达？",["避免税费上涨","为布置培训室做准备","替代被取消的订单","利用10月16日的促销活动"]),
      new ToeicQuestionTranslation("R-P7-TRAVEL-01",travelPassage,
        "酒店每晚房价是否符合公司的报销上限？",["符合，比上限低7美元","不符合，比上限高7美元","不符合，酒店费不可报销","符合，因为没有每晚限额"]),
      new ToeicQuestionTranslation("R-P7-TRAVEL-02",travelPassage,
        "两晚酒店住宿的税前总费用是多少？",["145美元","138美元","276美元","290美元"]),
      new ToeicQuestionTranslation("R-P7-TRAVEL-03",travelPassage,
        "Adrian 还需要补交什么证明材料？",["新的行程单","出租车逐项明细收据","另一张酒店收据","供应商合同"]),
      new ToeicQuestionTranslation("R-P7-TRAVEL-04",travelPassage,
        "Adrian 的出差在哪一天结束？",["11月4日","11月11日","11月5日","11月6日"]),
      new ToeicQuestionTranslation("R-P7-TRAVEL-05",travelPassage,
        "为什么银行卡对账单不足以支持出租车报销？",["公司政策排除出租车费用","金额超过出租车费用限额","政策要求逐项明细收据","报销已超过30天期限"]),
      new ToeicQuestionTranslation("R-P7-FILTER-01",filterPassage,
        "截至10月3日，还有多少个滤芯尚未到货？",["0个","1个","2个","4个"]),
      new ToeicQuestionTranslation("R-P7-FILTER-02",filterPassage,
        "第二批配送需要额外支付多少运费？",["12美元","24美元","30美元","0美元"]),
      new ToeicQuestionTranslation("R-P7-FILTER-03",filterPassage,
        "供应商计划什么时候发出剩余滤芯？",["10月9日","10月3日","10月5日","10月10日"]),
      new ToeicQuestionTranslation("R-P7-FILTER-04",filterPassage,
        "为什么供应商预计原发票不需要修改？",["产品单价降低了","余货保证在期限前送达","第一张发票取消了运费","仓库已经收到全部40件"]),
      new ToeicQuestionTranslation("R-P7-FILTER-05",filterPassage,
        "包含运费的原始发票总金额是多少？",["480美元","500美元","510美元","530美元"])
    ];
  }
}
