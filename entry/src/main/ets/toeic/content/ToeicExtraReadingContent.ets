import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/**
 * ORIGINAL supplementary Part 7 double/triple passages.
 * Status REVIEWED is an editorial candidate, NOT published until human QA.
 * Documents are stored once per group; individual questions keep stable IDs.
 * Evidence for cross-document items is separated with " || ".
 */
export class ToeicExtraReadingContent {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-VENUE",["R-P7-VENUE-01","R-P7-VENUE-02","R-P7-VENUE-03","R-P7-VENUE-04","R-P7-VENUE-05"],["DOCUMENT 1 — HARBOR CONFERENCE CENTER | BOOKING GUIDE\nThe Maple Room accommodates up to 55 attendees, while the Cedar Hall accommodates up to 90. Switching from Maple Room to Cedar Hall adds $160 to the rental fee. Requests to change rooms must reach the venue coordinator by September 12. Final catering numbers are due five business days before the event.","DOCUMENT 2 — EMAIL, SEPTEMBER 10\nTo: Harbor Conference Center\nSubject: October 7 workshop — booking HC-204\nWe originally reserved the Maple Room for 48 participants. Registration has now increased to 62, and we would like to move to Cedar Hall. Please keep the workshop date unchanged. We will confirm the final lunch count separately.\n— Min Seo, Training Team"]),
      new ToeicReadingGroup("P7-EX-DELIVERY",["R-P7-DELIVERY-01","R-P7-DELIVERY-02","R-P7-DELIVERY-03","R-P7-DELIVERY-04","R-P7-DELIVERY-05"],["DOCUMENT 1 — OFFICE EQUIPMENT ORDER PO-318\nTwenty-four monitors are scheduled for standard delivery by October 16. An express option costs an additional $80 and guarantees delivery by October 13. The express upgrade must be requested by 4 P.M. on October 10.","DOCUMENT 2 — INTERNAL MESSAGE, OCTOBER 9\nTo: Purchasing\nFacilities will begin fitting out the training room on October 15. We need all 24 new monitors on site before that work begins. If regular shipping cannot meet this deadline, please arrange the faster option, but obtain purchasing approval before adding a delivery fee.\n— Elena, Operations"]),
      new ToeicReadingGroup("P7-EX-TRAVEL",["R-P7-TRAVEL-01","R-P7-TRAVEL-02","R-P7-TRAVEL-03","R-P7-TRAVEL-04","R-P7-TRAVEL-05"],["DOCUMENT 1 — TRAVEL EXPENSE RULES\nEmployees may claim up to $145 per hotel night before taxes when traveling on approved business. Itemized receipts are required for hotel and taxi expenses. Claims must be submitted within 30 calendar days after the trip ends.","DOCUMENT 2 — TRIP RECORD\nProject engineer Adrian Lee traveled to the Portland supplier meeting from November 4 to November 6. The attached itemized hotel receipt shows two nights at $138 per night before taxes. The taxi expense summary shows $48 but includes only a card statement.","DOCUMENT 3 — FINANCE FOLLOW-UP, NOVEMBER 11\nTo: Adrian Lee\nWe received your draft expense claim for the Portland trip. The hotel receipt is complete. Please upload the itemized taxi receipt before submitting the claim; a card statement alone does not satisfy our documentation rule. No other changes are needed."])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-VENUE-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.PURPOSE,'',"Why did Min Seo write to the conference center?",["To cancel a workshop","To change the workshop date","To request a larger room","To reduce the catering order"],2,
        "邮件要求将 Maple Room 改为 Cedar Hall，培训日期不变。","we would like to move to Cedar Hall.","move to Cedar Hall = request a larger venue",65,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-VENUE"),
      new ToeicQuestion("R-P7-VENUE-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why is the original room no longer suitable?",["Registration is higher than its capacity","Catering is unavailable there","The venue is closed on October 7","The coordinator raised its rental rate"],0,
        "原房间最多55人，报名人数已增至62人；需要合并两份材料。","The Maple Room accommodates up to 55 attendees || Registration has now increased to 62","room capacity = maximum attendees",82,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-VENUE"),
      new ToeicQuestion("R-P7-VENUE-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"What additional rental charge applies to the requested change?",["$55","$90","$62","$160"],3,
        "预订指南中 Cedar Hall 升级费用为160美元；不要把容量当作价格。","Switching from Maple Room to Cedar Hall adds $160 to the rental fee.","additional rental charge = adds to the rental fee",60,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-VENUE"),
      new ToeicQuestion("R-P7-VENUE-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"What information will the training team provide later?",["The booking reference","The final lunch count","The location of the venue","The workshop date"],1,
        "邮件最后明确 final lunch count 会另行确认。","We will confirm the final lunch count separately.","provide later = confirm separately",53,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-VENUE"),
      new ToeicQuestion("R-P7-VENUE-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Was the request for a different room sent by the stated deadline?",["No, it was sent after September 12","No, room changes were not permitted","Yes, it was emailed on September 10","Yes, because the workshop starts in November"],2,
        "指南要求9月12日前提出调整，邮件日期为9月10日。","Requests to change rooms must reach the venue coordinator by September 12 || DOCUMENT 2 — EMAIL, SEPTEMBER 10","by September 12 = on or before September 12",84,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-VENUE"),
      new ToeicQuestion("R-P7-DELIVERY-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Which delivery option would meet Operations' required schedule?",["Standard delivery","Express delivery","Either option","Neither option"],1,
        "标准送达日10月16日晚于10月15日的施工开始；快递10月13日送达，能满足要求。","standard delivery by October 16 || guarantees delivery by October 13 || begin fitting out the training room on October 15","meet the required schedule = arrive before fitting-out begins",88,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-DELIVERY"),
      new ToeicQuestion("R-P7-DELIVERY-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"What must Purchasing obtain before accepting an extra delivery charge?",["A new order number","A safety inspection","A signed delivery note","Purchasing approval"],3,
        "内部邮件明确加收运费前须获得采购审批。","obtain purchasing approval before adding a delivery fee.","obtain approval = secure authorization",56,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-DELIVERY"),
      new ToeicQuestion("R-P7-DELIVERY-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"How much would the express option add to the order?",["$80","$24","$13","$16"],0,
        "订单说明 express option 额外收取80美元；其他数字来自数量或日期。","An express option costs an additional $80","add to the order = additional charge",56,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-DELIVERY"),
      new ToeicQuestion("R-P7-DELIVERY-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"By when must the express upgrade be requested?",["October 9 at 4 P.M.","October 15 at noon","October 10 at 4 P.M.","October 16 at 4 P.M."],2,
        "定位 must be requested by，截止时间为10月10日下午4点。","The express upgrade must be requested by 4 P.M. on October 10.","be requested by = deadline for request",59,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-DELIVERY"),
      new ToeicQuestion("R-P7-DELIVERY-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.PURPOSE,'',"Why does Operations want the monitors delivered early?",["To avoid a tax increase","To prepare for fitting out a training room","To replace a cancelled order","To use an October 16 promotion"],1,
        "内部消息说明10月15日起布置培训室，显示器须在开工前到货。","Facilities will begin fitting out the training room on October 15. We need all 24 new monitors on site before that work begins.","delivered early = on site before installation work",68,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-DELIVERY"),
      new ToeicQuestion("R-P7-TRAVEL-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Does the nightly hotel rate meet the company's reimbursement limit?",["Yes, the rate is $7 below the limit","No, the rate is $7 above the limit","No, hotels are not reimbursable","Yes, because there is no nightly limit"],0,
        "政策每晚最高145美元（税前），发票每晚138美元，低于上限7美元。","up to $145 per hotel night before taxes || two nights at $138 per night before taxes","meet the limit = fall within the allowed amount",90,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAVEL"),
      new ToeicQuestion("R-P7-TRAVEL-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is the hotel charge for two nights before taxes?",["$145","$138","$276","$290"],2,
        "住宿两晚、每晚138美元，税前金额为276美元；别把限额145当成实际价格。","two nights at $138 per night before taxes || up to $145 per hotel night before taxes","two nights at $138 = $276 before taxes",87,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAVEL"),
      new ToeicQuestion("R-P7-TRAVEL-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Which supporting document must Adrian still provide?",["A new itinerary","An itemized taxi receipt","Another hotel receipt","A supplier contract"],1,
        "旅行记录只有出租车刷卡对账单，财务明确要求补充出租车逐项收据。","taxi expense summary shows $48 but includes only a card statement || Please upload the itemized taxi receipt","supporting document = itemized expense receipt",86,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAVEL"),
      new ToeicQuestion("R-P7-TRAVEL-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"When did Adrian's trip end?",["November 4","November 11","November 5","November 6"],3,
        "行程记录写明出差从11月4日至11月6日。","from November 4 to November 6","trip end = last date of travel",48,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAVEL"),
      new ToeicQuestion("R-P7-TRAVEL-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why is the card statement insufficient for the taxi claim?",["Taxi travel is excluded from company policy","The amount is above the taxi limit","The policy requires an itemized receipt","The claim was made more than 30 days late"],2,
        "政策要求酒店和出租车均提供逐项收据，财务提醒刷卡对账单不能替代。","Itemized receipts are required for hotel and taxi expenses || a card statement alone does not satisfy our documentation rule","itemized receipt = proof showing individual charges",92,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAVEL")
    ];
  }
}
