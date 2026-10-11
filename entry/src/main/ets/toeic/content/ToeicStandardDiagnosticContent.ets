import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Optional medium-difficulty diagnostic. Separate from Day 1's 12-question quick baseline. */
export class ToeicStandardDiagnosticContent {
  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-DX-P5-01",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.WORD_FORM,"",
        "The marketing department will send updated brochures to all registered _____.",["attend","attendees","attending","attendance"],1,
        "to all registered 后需复数名词 attendees 指所有已注册参会者。","","registered attendees = people who registered",18,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P5-02",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VOICE,"",
        "All electronic invoices must be _____ by the finance team before payment.",["review","reviewed","reviewing","reviewer"],1,
        "must be 后接过去分词；发票是被审核的，因此选 reviewed。","","be reviewed = be checked",16,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P5-03",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.CONJUNCTION,"",
        "The revised report will be published _____ the committee approves the final figures.",["once","despite","during","because of"],0,
        "空格后接完整句子 the committee approves...，once 表示一旦批准便发布。","","once = as soon as",18,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P5-04",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.COLLOCATION,"",
        "Employees must complete the online survey no later _____ Friday.",["then","than","that","from"],1,
        "固定表达 no later than Friday，表示最迟周五完成。","","no later than = by",15,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P5-05",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VOICE,"",
        "The updated policy _____ to all regional offices last week.",["send","was sent","has send","sending"],1,
        "last week 表明过去时间，policy 被发送，使用一般过去时被动 was sent。","","was sent = was distributed",18,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P5-06",ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VOCABULARY,"",
        "To reduce costs, the company plans to _____ its office supplies from one vendor.",["purchase","participate","postpone","prevent"],0,
        "purchase ... from one vendor 表示从一家供应商采购办公用品。","","purchase = buy",19,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P6-01",ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.CONTEXT,"Subject: Temporary Garage Closure\nThe employee parking garage will be closed this Saturday for resurfacing. _____(1)_____, staff attending weekend training must park in the public lot across the street. The maintenance crew expects to finish by Sunday evening. Normal garage access _____(2)_____ resume on Monday morning.",
        "Which phrase best fits blank (1)?",["During this time","Last year","In contrast","For this reason only"],0,
        "停车楼周六关闭，During this time 连接同一时段替代停车安排。","","during this time = while the garage is closed",36,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P6-02",ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.VERB,"Subject: Temporary Garage Closure\nThe employee parking garage will be closed this Saturday for resurfacing. _____(1)_____, staff attending weekend training must park in the public lot across the street. The maintenance crew expects to finish by Sunday evening. Normal garage access _____(2)_____ resume on Monday morning.",
        "Choose the correct word for blank (2).",["were","will","being","has"],1,
        "主语 access 后接动词原形 resume；星期一仍在未来，用 will resume。","","will resume = will restart",32,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P7-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.PURPOSE,"Subject: Updated Workshop Schedule\nDear Participants,\nThe customer service workshop originally scheduled for 9:00 A.M. on Monday will now begin at 10:30 A.M. Check-in opens at 10:00 A.M. in Room B. Registered participants do not need to register again. Please confirm whether you will attend by Thursday afternoon.\nBest regards,\nTraining Office",
        "Why did the Training Office send this email?",["To announce a change in the workshop start time","To cancel all registrations","To request additional workshop instructors","To change the workshop location to another city"],0,
        "主旨为开课时间由9:00改为10:30；无需重新注册。","will now begin at 10:30 A.M.","announce a change = inform participants of a revised time",62,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P7-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"Subject: Updated Workshop Schedule\nDear Participants,\nThe customer service workshop originally scheduled for 9:00 A.M. on Monday will now begin at 10:30 A.M. Check-in opens at 10:00 A.M. in Room B. Registered participants do not need to register again. Please confirm whether you will attend by Thursday afternoon.\nBest regards,\nTraining Office",
        "At what time will check-in begin?",["9:00 A.M.","10:00 A.M.","10:30 A.M.","Thursday afternoon"],1,
        "定位 Check-in opens，文中明确写10:00 A.M.，不要与开课10:30混淆。","Check-in opens at 10:00 A.M. in Room B.","check-in opens = registration desk becomes available",48,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P7-03",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.CROSS_DOCUMENT,"DOCUMENT 1 — RETURN POLICY\nFurniture may be returned within 14 days of delivery if the item is unused and in its original packaging. Customers must contact Support before shipping any return.\n\nDOCUMENT 2 — CUSTOMER MESSAGE\nTo: Support\nMy office chair arrived on September 7. I noticed a scratch when I opened the shipping carton, but I have not used the chair and the original packaging is intact. Today is September 16. Please advise me on the return procedure.",
        "Why does the customer's chair appear to meet the stated return conditions?",["The item is unused, packaged, and the request is within fourteen days","The chair has already been repaired","The manufacturer waived the return fee","The item was delivered more than one month ago"],0,
        "Policy要求14天内、未使用、保留原包装；邮件在收货9天后发出，且顾客明确说明未使用、包装完好。","within 14 days of delivery if the item is unused and in its original packaging; arrived on September 7; Today is September 16; have not used the chair","meets return conditions = qualifies under the stated rules",86,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion("R-DX-P7-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.CROSS_DOCUMENT,"DOCUMENT 1 — RETURN POLICY\nFurniture may be returned within 14 days of delivery if the item is unused and in its original packaging. Customers must contact Support before shipping any return.\n\nDOCUMENT 2 — CUSTOMER MESSAGE\nTo: Support\nMy office chair arrived on September 7. I noticed a scratch when I opened the shipping carton, but I have not used the chair and the original packaging is intact. Today is September 16. Please advise me on the return procedure.",
        "What must the customer do before shipping the chair back?",["Visit the regional warehouse","Contact Support","Buy a replacement chair","Wait until the return period ends"],1,
        "Policy写明 Customers must contact Support before shipping any return；顾客邮件正是在联系支持团队。","Customers must contact Support before shipping any return.","contact Support = reach the service team",73,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET)
    ];
  }
}
