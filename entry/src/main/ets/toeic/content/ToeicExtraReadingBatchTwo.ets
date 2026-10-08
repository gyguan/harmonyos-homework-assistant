import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Original supplementary Part 7 candidates. Human editorial signoff required before publication. */
export class ToeicExtraReadingBatchTwo {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-ONBOARD",["R-P7-ONBOARD-01","R-P7-ONBOARD-02","R-P7-ONBOARD-03","R-P7-ONBOARD-04","R-P7-ONBOARD-05"],["DOCUMENT 1 — NEW HIRE ORIENTATION GUIDE\nThe January 12 orientation begins at 9:00 A.M. in Room B on the second floor. New hires must complete online registration by 5:00 P.M. on January 8. Anyone without a permanent building badge should check in with Security for a day pass before 8:45 A.M. A government-issued photo ID is required to obtain the pass.","DOCUMENT 2 — EMAIL, JANUARY 7\nTo: Human Resources\nSubject: January 12 orientation\nMy registration confirmation lists a seat in the January 12 session. My permanent badge will not be ready until Tuesday, January 13. I plan to arrive at 8:20 A.M. on Monday and will bring my passport. Please let me know if anything else is needed.\n— Nora Park"]),
      new ToeicReadingGroup("P7-EX-FILTER",["R-P7-FILTER-01","R-P7-FILTER-02","R-P7-FILTER-03","R-P7-FILTER-04","R-P7-FILTER-05"],["DOCUMENT 1 — SUPPLY AGREEMENT SA-218\nThe warehouse ordered 40 replacement air filters at $12 each. A single $30 shipping charge applies to the full order, including split deliveries. Items that remain undelivered after October 10 qualify for a credit note; partial shipments received earlier do not require an invoice revision.","DOCUMENT 2 — WAREHOUSE RECEIVING LOG, OCTOBER 3\nOrder SA-218: 38 filters received and counted. The accompanying invoice lists all 40 filters at the agreed unit price, plus the single shipping fee. The receiving manager reported the two missing units to the supplier that afternoon.","DOCUMENT 3 — SUPPLIER EMAIL, OCTOBER 5\nWe checked the packing record and confirmed that 38 filters were sent in the first box. The remaining two filters are scheduled to ship on October 9 by guaranteed next-day delivery, arriving on October 10. We will not add any shipping charge. The original invoice can remain unchanged if the balance arrives by October 10."])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-ONBOARD-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.PURPOSE,'',"Why did Nora contact Human Resources?",["To cancel her registration","To explain her building-access situation","To request a different orientation date","To ask for a training schedule"],1,
        "Nora 说明正式门禁卡要到周二才发放，并告知提前抵达及携带证件的计划。","My permanent badge will not be ready until Tuesday, January 13.","building-access situation = badge not ready",64,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-ONBOARD"),
      new ToeicQuestion("R-P7-ONBOARD-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What should Nora do before 8:45 A.M. on January 12?",["Obtain a day pass from Security","Register online for the session","Meet the trainer in Room B","Collect her permanent badge"],0,
        "指南要求尚无正式门禁卡者在8:45前领取临时通行证，而邮件说明 Nora 的正式卡要到次日才有。","Anyone without a permanent building badge should check in with Security for a day pass before 8:45 A.M. || My permanent badge will not be ready until Tuesday, January 13.","check in for a day pass = obtain temporary building access",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-ONBOARD"),
      new ToeicQuestion("R-P7-ONBOARD-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"Where will the orientation take place?",["In the security office","In the main auditorium","In Room B on the second floor","In an online meeting room"],2,
        "入职指南首句明确指出 Room B on the second floor。","in Room B on the second floor","held in = takes place in",48,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-ONBOARD"),
      new ToeicQuestion("R-P7-ONBOARD-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why should Nora bring her passport?",["To confirm her job title","To complete her registration","To receive a parking permit","To show the photo ID needed for a day pass"],3,
        "指南要求办理临时通行证提供政府签发的带照片证件，邮件里 Nora 将携带护照。","A government-issued photo ID is required to obtain the pass. || I plan to arrive at 8:20 A.M. on Monday and will bring my passport.","passport = government-issued photo ID",87,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-ONBOARD"),
      new ToeicQuestion("R-P7-ONBOARD-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"By when must new employees complete online registration?",["January 7 at 9:00 A.M.","January 12 at 8:45 A.M.","January 8 at 5:00 P.M.","January 13 at 5:00 P.M."],2,
        "指南明确规定报名截止在1月8日下午5点。","complete online registration by 5:00 P.M. on January 8","registration deadline = last permitted time to register",56,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-ONBOARD"),
      new ToeicQuestion("R-P7-FILTER-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How many filters had not arrived as of October 3?",["None","One","Two","Four"],2,
        "订单共40件，而10月3日验收入库38件，尚欠2件。","ordered 40 replacement air filters || 38 filters received and counted","undelivered filters = ordered quantity minus received quantity",87,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-FILTER"),
      new ToeicQuestion("R-P7-FILTER-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much extra will the second delivery cost in shipping fees?",["$12","$24","$30","$0"],3,
        "合同约定整单只收一次30美元运费，供应商邮件也确认补发不另外收运费。","A single $30 shipping charge applies to the full order, including split deliveries. || We will not add any shipping charge.","extra shipping fee = additional delivery charge",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-FILTER"),
      new ToeicQuestion("R-P7-FILTER-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"When is the supplier planning to send the remaining filters?",["October 9","October 3","October 5","October 10"],0,
        "供应商邮件直接说明剩余两件计划10月9日发出。","The remaining two filters are scheduled to ship on October 9.","scheduled to ship = planned dispatch date",58,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-FILTER"),
      new ToeicQuestion("R-P7-FILTER-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why does the supplier expect the original invoice to remain valid?",["The unit price was reduced","The remaining units are guaranteed to arrive by the deadline","The shipping fee was removed from the first invoice","The warehouse already received all 40 filters"],1,
        "合同规定10月10日后仍未到货的商品可获得贷项通知；供应商承诺10月9日发货、10月10日送达，因此预计无需修改原账单。","Items that remain undelivered after October 10 qualify for a credit note || The remaining two filters are scheduled to ship on October 9 by guaranteed next-day delivery, arriving on October 10.","invoice remains valid if remaining units arrive by the stated deadline",94,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-FILTER"),
      new ToeicQuestion("R-P7-FILTER-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is the total amount on the original invoice, including shipping?",["$480","$500","$510","$530"],2,
        "40件每件12美元共480美元，再加一次30美元运费，总额510美元；验收数量不改变原发票数量。","ordered 40 replacement air filters at $12 each. A single $30 shipping charge applies || The accompanying invoice lists all 40 filters at the agreed unit price, plus the single shipping fee.","original invoice total = item price times quantity plus one shipping charge",94,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-FILTER")
    ];
  }
}
