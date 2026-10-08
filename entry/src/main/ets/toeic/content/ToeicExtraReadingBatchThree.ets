import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Original Part 7 source sets; all questions are editorial candidates until recorded signoff. */
export class ToeicExtraReadingBatchThree {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-SUPPORT",["R-P7-SUPPORT-01","R-P7-SUPPORT-02","R-P7-SUPPORT-03","R-P7-SUPPORT-04","R-P7-SUPPORT-05"],["DOCUMENT 1 — NORTHLINE BUSINESS SUPPORT PLAN\nThe standard support plan costs $400 per month. During weekday service hours (8 A.M. to 6 P.M.), priority support tickets receive an initial response within two hours. An unplanned service interruption lasting longer than 90 consecutive minutes qualifies for a one-time credit of 10 percent of the monthly fee on the next invoice. Scheduled maintenance announced at least 48 hours in advance does not qualify for a credit.","DOCUMENT 2 — INCIDENT RECORD NT-118\nTuesday, May 12 | Internet service interruption\nService unavailable: 10:10 A.M.–12:05 P.M. (115 consecutive minutes)\nInitial engineer response: 10:50 A.M.\nCause: unexpected failure of a network device\nService restored: 12:05 P.M.\nThe June invoice is scheduled to show the normal $400 monthly fee before adjustments.","DOCUMENT 3 — EMAIL, MAY 13\nTo: Accounts Team\nPlease review incident NT-118 before issuing the June invoice. I expect the credit described in our support agreement. Separately, our planned maintenance window on May 15, 10–11 P.M., was announced to customers on May 11. That work should be treated as scheduled maintenance.\n— Rowan, Service Manager"]),
      new ToeicReadingGroup("P7-EX-RETAIL",["R-P7-RETAIL-01","R-P7-RETAIL-02","R-P7-RETAIL-03","R-P7-RETAIL-04","R-P7-RETAIL-05"],["DOCUMENT 1 — APRIL ONLINE APPAREL OFFER\nFrom April 1 through April 7, online clothing purchases with a merchandise subtotal of at least $100 before tax qualify for free standard shipping. Gift cards do not count toward the minimum. Customers who choose express shipping pay an additional $18. Clothing purchased online may be returned within 30 days with the original receipt, except for personalized items.","DOCUMENT 2 — ORDER CONFIRMATION S-822 | APRIL 5\nCustomer: Helen Wu\nCotton shirt: $64\nSpring jacket: $48\nDigital gift card: $30\nThe clothing subtotal is $112 before tax. The customer selected express shipping rather than standard shipping. Neither clothing item was personalized. Helen has kept the original electronic receipt."])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-SUPPORT-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why does incident NT-118 qualify for a service credit?",["It interrupted service for more than 90 minutes without notice","It occurred during a scheduled maintenance window","It lasted fewer than two hours","It generated two separate service tickets"],0,
        "服务协议规定意外中断超过连续90分钟可获抵扣，而事件记录为意外停机115分钟。","An unplanned service interruption lasting longer than 90 consecutive minutes qualifies || (115 consecutive minutes)","unplanned interruption over 90 minutes = credit-eligible outage",90,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-SUPPORT"),
      new ToeicQuestion("R-P7-SUPPORT-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much credit should appear on the June invoice for NT-118?",["$10","$40","$90","$115"],1,
        "协议按月费的10%抵扣，月费400美元，因此抵扣40美元。","The standard support plan costs $400 per month. || a one-time credit of 10 percent of the monthly fee","10 percent of $400 = $40",91,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-SUPPORT"),
      new ToeicQuestion("R-P7-SUPPORT-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"When did the engineer first respond to NT-118?",["10:10 A.M.","12:05 P.M.","10:50 A.M.","6:00 P.M."],2,
        "事件日志的 Initial engineer response 明确为上午10:50。","Initial engineer response: 10:50 A.M.","initial response = first reply",55,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-SUPPORT"),
      new ToeicQuestion("R-P7-SUPPORT-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why would the May 15 maintenance window not qualify for an outage credit?",["It happened on a Tuesday morning","It involved the same network device","It lasted exactly 115 minutes","It was announced at least 48 hours beforehand"],3,
        "协议排除提前48小时宣布的计划维护，邮件指出5月11日已告知5月15日的维护。","Scheduled maintenance announced at least 48 hours in advance does not qualify for a credit. || our planned maintenance window on May 15, 10–11 P.M., was announced to customers on May 11","announced at least 48 hours ahead = excluded scheduled work",87,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-SUPPORT"),
      new ToeicQuestion("R-P7-SUPPORT-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Did the initial response meet the priority-ticket response target?",["No, it took longer than two hours","No, the ticket began outside service hours","Yes, it took forty minutes","Yes, because the problem was resolved before noon"],2,
        "工作日服务时段内要求2小时内首次响应；事件10:10开始、10:50响应，相差40分钟。","priority support tickets receive an initial response within two hours || Service unavailable: 10:10 A.M.–12:05 P.M. || Initial engineer response: 10:50 A.M.","respond within two hours = initial reply no later than 12:10",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-SUPPORT"),
      new ToeicQuestion("R-P7-RETAIL-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Does order S-822 meet the minimum amount for free standard shipping?",["No, gift cards are excluded from the offer","Yes, the clothing subtotal exceeds $100","No, the order was placed after April 7","Yes, all gift cards qualify as clothing"],1,
        "订单中的服装小计为112美元，超过活动要求的税前100美元门槛；礼品卡不参与计算。","clothing purchases with a merchandise subtotal of at least $100 before tax qualify || The clothing subtotal is $112 before tax.","clothing subtotal of $112 = exceeds the $100 minimum",83,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-RETAIL"),
      new ToeicQuestion("R-P7-RETAIL-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"How much does express shipping add to the order?",["$30","$12","$100","$18"],3,
        "活动规定选择快递配送额外支付18美元。","Customers who choose express shipping pay an additional $18.","additional express shipping fee = $18",50,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-RETAIL"),
      new ToeicQuestion("R-P7-RETAIL-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What amount from order S-822 counts toward the promotion's clothing minimum?",["$112","$142","$64","$30"],0,
        "订单明确服装小计112美元，礼品卡30美元不计入；无需将所有商品相加。","Gift cards do not count toward the minimum. || The clothing subtotal is $112 before tax.","eligible merchandise = clothing excluding gift cards",81,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-RETAIL"),
      new ToeicQuestion("R-P7-RETAIL-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What would Helen need in order to return the jacket under the stated policy?",["A second purchase during April","A handwritten note from the manufacturer","The original receipt and a return within 30 days","A replacement gift card"],2,
        "政策要求30天内持原始收据且非定制商品，确认单显示夹克不是定制且已保存电子收据。","Clothing purchased online may be returned within 30 days with the original receipt, except for personalized items. || Neither clothing item was personalized. Helen has kept the original electronic receipt.","return condition = receipt, 30-day limit and nonpersonalized item",94,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-RETAIL"),
      new ToeicQuestion("R-P7-RETAIL-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"Which item is specifically excluded from the minimum-purchase calculation?",["Cotton shirt","Digital gift card","Spring jacket","All apparel"],1,
        "活动规则明确 Gift cards do not count toward the minimum。","Gift cards do not count toward the minimum.","excluded from minimum = not counted toward qualifying spend",52,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-RETAIL")
    ];
  }
}
