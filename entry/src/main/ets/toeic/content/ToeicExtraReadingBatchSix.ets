import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** AI-reviewed shared Part 7 PERDIEM/CATERING groups, published as complete bundles. */
export class ToeicExtraReadingBatchSix {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-PERDIEM",["R-P7-PERDIEM-01","R-P7-PERDIEM-02","R-P7-PERDIEM-03","R-P7-PERDIEM-04","R-P7-PERDIEM-05"],["DOCUMENT 1 — CORPORATE TRAVEL REIMBURSEMENT RULES\nFor approved overnight business trips, employees receive a meal per diem of $45 for each calendar day of travel, including the departure and return dates. Hotel accommodation is reimbursed up to $140 per room-night if an itemized receipt is supplied. Airport shuttle fares are reimbursed in full with a receipt, but personal entertainment is not covered. Claims must be submitted within seven calendar days after returning.","DOCUMENT 2 — HOTEL PAYMENT RECEIPT\nGuest: Jordan Lee\nCheck-in: September 14\nCheck-out: September 16\nStandard room: two nights at $132 per night\nTotal lodging paid: $264\nPayment confirmed; itemized receipt provided.","DOCUMENT 3 — EMAIL TO FINANCE, SEPTEMBER 20\nI traveled on an approved business trip from September 14 to September 16 and returned home on September 16. Along with the attached hotel receipt, I have a $26 airport shuttle receipt. I also paid $18 to visit a museum in my free time. Before I file the claim today, could you confirm which amounts qualify?\n— Jordan Lee"]),
      new ToeicReadingGroup("P7-EX-CATERING",["R-P7-CATERING-01","R-P7-CATERING-02","R-P7-CATERING-03","R-P7-CATERING-04","R-P7-CATERING-05"],["DOCUMENT 1 — EASTSIDE CONFERENCE CENTER SERVICE TERMS\nHall A accommodates up to 160 attendees; Hall B accommodates up to 80. On October 12, Hall A will be unavailable from 9 A.M. to noon for scheduled maintenance, but events beginning at or after 1 P.M. may proceed. Catering orders may be changed through October 8 at 5 P.M. Coffee service costs $4 per attendee served and boxed lunches cost $8 each.","DOCUMENT 2 — RESERVATION CONFIRMATION, OCTOBER 5\nEvent: Regional Project Forum\nDate and start: October 12, 2 P.M.\nRoom: Hall A\nExpected attendees: 120\nCatering: 100 coffee servings and 120 boxed lunches.\nOriginal catering cost: $1,360.","DOCUMENT 3 — ORGANIZER EMAIL, OCTOBER 7\nTo: Event Services\nOur registration count has increased to 135. Please keep Hall A and our 2 P.M. start time, but update catering to 135 coffee servings and 135 boxed lunches. Could you confirm the revised cost? Thank you.\n— Sarah\nEVENT SERVICES RESPONSE, OCTOBER 7, 4 P.M.\nThe revised quantities are accepted. We will send an updated catering invoice."])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-PERDIEM-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much of Jordan's hotel expense is eligible for reimbursement?",["$280","$264","$132","$140"],1,
        "住宿上限每晚140美元；收据显示两晚每晚132美元，总额264美元均在限额内。","Hotel accommodation is reimbursed up to $140 per room-night if an itemized receipt is supplied. || Standard room: two nights at $132 per night","actual nightly room rate below the cap = full lodging cost eligible",85,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-PERDIEM"),
      new ToeicQuestion("R-P7-PERDIEM-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much meal per diem can Jordan claim for the trip?",["$135","$90","$45","$180"],0,
        "规则包括出发和返程日，9月14日至16日共3个日历日，3乘以45美元为135美元。","a meal per diem of $45 for each calendar day of travel, including the departure and return dates. || I traveled on an approved business trip from September 14 to September 16","three travel calendar days × $45 per diem = $135",91,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-PERDIEM"),
      new ToeicQuestion("R-P7-PERDIEM-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Which expense must Jordan leave out of the claim?",["The airport shuttle fare","The hotel accommodation","The meal per diem","The museum admission"],3,
        "政策不报销个人娱乐；邮件说明18美元博物馆门票是个人闲暇开支。","personal entertainment is not covered. || I also paid $18 to visit a museum in my free time.","personal entertainment = museum admission for leisure",84,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-PERDIEM"),
      new ToeicQuestion("R-P7-PERDIEM-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is the deadline for Jordan's travel claim?",["September 20","September 16","September 23","September 30"],2,
        "规则规定返程后七个自然日内提交，Jordan 于9月16日返回，因此9月23日为截止日。","within seven calendar days after returning. || returned home on September 16.","seven days after September 16 = September 23",92,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-PERDIEM"),
      new ToeicQuestion("R-P7-PERDIEM-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is Jordan's total eligible reimbursement, including meals?",["$443","$425","$399","$407"],1,
        "两晚住宿264美元、三天餐补135美元和机场班车26美元可报销，合计425美元；博物馆18美元不计入。","a meal per diem of $45 for each calendar day of travel, including the departure and return dates. || Total lodging paid: $264 || I traveled on an approved business trip from September 14 to September 16 and returned home on September 16. Along with the attached hotel receipt, I have a $26 airport shuttle receipt.","264 + (45 × 3) + 26 = 425",107,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-PERDIEM"),
      new ToeicQuestion("R-P7-CATERING-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Which room can hold all 135 expected attendees?",["Hall B only","Neither Hall A nor Hall B","Hall A only","Both rooms"],2,
        "会务条款显示 Hall A 容量160、Hall B 容量80；报名人数增至135，因此仅 Hall A 合适。","Hall A accommodates up to 160 attendees; Hall B accommodates up to 80. || Our registration count has increased to 135.","135 attendees fit the 160-person room, not the 80-person room",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-CATERING"),
      new ToeicQuestion("R-P7-CATERING-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much more will the revised catering order cost?",["$260","$140","$360","$240"],0,
        "新订单135杯咖啡乘4美元加135份午餐乘8美元等于1620美元，原订1360美元，新增260美元。","Coffee service costs $4 per attendee served and boxed lunches cost $8 each. || Original catering cost: $1,360. || update catering to 135 coffee servings and 135 boxed lunches.","revised $1,620 minus original $1,360 = $260 increase",104,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-CATERING"),
      new ToeicQuestion("R-P7-CATERING-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Will the scheduled maintenance prevent the event from starting at the reserved time?",["Yes, Hall A will be unavailable all day","Yes, maintenance continues until 3 P.M.","Yes, the forum must move to Hall B","No, the event begins after Hall A reopens"],3,
        "维修仅安排上午9点到中午，下午1点及以后可举办活动；预订开场时间为下午2点。","Hall A will be unavailable from 9 A.M. to noon for scheduled maintenance, but events beginning at or after 1 P.M. may proceed. || Date and start: October 12, 2 P.M.","after 1 P.M. = allowed despite earlier maintenance",88,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-CATERING"),
      new ToeicQuestion("R-P7-CATERING-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Was the change to catering quantities accepted before the stated cutoff?",["No, it was accepted on October 12","No, all changes needed approval by October 5","Yes, the response came on October 7","Yes, the deadline was October 12"],2,
        "会务条款允许最迟在10月8日17点（含该时刻）修改订单，服务方已于10月7日16点确认并接受修改。","Catering orders may be changed through October 8 at 5 P.M. || EVENT SERVICES RESPONSE, OCTOBER 7, 4 P.M. || The revised quantities are accepted.","accepted on October 7 = before October 8 deadline",94,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-CATERING"),
      new ToeicQuestion("R-P7-CATERING-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What should the updated invoice show as the total catering charge?",["$1,360","$1,620","$1,500","$1,800"],1,
        "更新后为135杯咖啡和135份午餐，单价4美元与8美元，合计1620美元。","Coffee service costs $4 per attendee served and boxed lunches cost $8 each. || update catering to 135 coffee servings and 135 boxed lunches.","135 × ($4 + $8) = $1,620",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.PUBLISHED,1,'','',0,0,"P7-EX-CATERING")
    ];
  }
}
