import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Original shared Part 7 articles. Draft content needs signed editorial review. */
export class ToeicExtraReadingBatchFive {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-MIGRATION",["R-P7-MIGRATION-01","R-P7-MIGRATION-02","R-P7-MIGRATION-03","R-P7-MIGRATION-04","R-P7-MIGRATION-05"],["DOCUMENT 1 — COMPANY SYSTEM NOTICE\nThe client-records portal will be unavailable for a scheduled system migration on October 17 from 9 P.M. to 11 P.M. Staff should export any reports needed for the following morning no later than October 16. After the migration, users must sign in again using their individual company accounts. The database contents will remain unchanged.","DOCUMENT 2 — HELP DESK INSTRUCTIONS\nTo access the updated client-records portal, open the company intranet and select Client Records. If your existing password is rejected, use the password-reset link. Do not share login credentials with colleagues. For assistance, contact the internal help desk; support begins at 7 A.M.","DOCUMENT 3 — EMAIL, OCTOBER 15\nTo: Help Desk\nI have to present the September client report at 8 A.M. on October 18. I normally download it just before the meeting. I also need to log in from my laptop at 7:30 A.M. that day. Is there anything I should do in advance?\n— Melissa, Sales"]),
      new ToeicReadingGroup("P7-EX-LICENSE",["R-P7-LICENSE-01","R-P7-LICENSE-02","R-P7-LICENSE-03","R-P7-LICENSE-04","R-P7-LICENSE-05"],["DOCUMENT 1 — WORKPLACE SOFTWARE PRICING\nA monthly team license costs $50 per active user. Orders for 10 or more licenses receive a 15 percent discount on license fees only. New customer accounts have a one-time setup charge of $60. The setup charge is not discounted. Teams may add licenses during the month, but any increase will be billed on the next invoice.","DOCUMENT 2 — PURCHASE REQUEST, NOVEMBER 3\nRequesting department: Customer Support\nWe would like to open a new team account with 10 active-user licenses beginning December 1. Our approved budget covers the first month of access and the initial setup charge. We may need two additional users in January, but please do not add them to the first order.\n— Olivia, Support Manager","DOCUMENT 3 — BILLING EMAIL, NOVEMBER 4\nTo: Olivia\nWe have received the purchase request for 10 licenses and can activate the account on December 1. The first invoice will reflect the volume discount and the one-time setup charge. Any future additional licenses will be invoiced separately after you authorize the increase.\n— Finance Team"])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-MIGRATION-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What should Melissa do before the system migration?",["Share her account password with a colleague","Export the September report by October 16","Request a new company laptop","Move her presentation to October 17"],1,
        "通知要求次日上午需要的报告须在10月16日前导出，而 Melissa 将在10月18日上午8点展示报告。","Staff should export any reports needed for the following morning no later than October 16. || I have to present the September client report at 8 A.M. on October 18.","export in advance = download before the scheduled outage",93,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-MIGRATION"),
      new ToeicQuestion("R-P7-MIGRATION-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How should Melissa access the updated portal on October 18?",["Reuse a colleague's credentials","Wait until the next weekly update","Open the intranet and sign in with her own account","Contact an external vendor to activate access"],2,
        "系统通知要求迁移后重新登录，帮助台指引使用内网入口与个人账号。","After the migration, users must sign in again using their individual company accounts. || To access the updated client-records portal, open the company intranet and select Client Records.","sign in again = reauthenticate using personal account",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-MIGRATION"),
      new ToeicQuestion("R-P7-MIGRATION-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"When is the portal expected to become available after the migration?",["At 11 P.M. on October 17","At 9 P.M. on October 17","At 7 A.M. on October 18","At 8 A.M. on October 18"],0,
        "通知给出的计划维护时段为10月17日21:00至23:00，因此计划在23:00结束。","on October 17 from 9 P.M. to 11 P.M.","planned availability = after the scheduled 11 P.M. end",50,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-MIGRATION"),
      new ToeicQuestion("R-P7-MIGRATION-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What should Melissa do if her original password is rejected?",["Wait for the database to be rebuilt","Use another employee's account","Export the report from the old portal","Use the password-reset link"],3,
        "帮助台明确指示如果旧密码不可用应使用重置链接；迁移通知明确使用个人账号。","users must sign in again using their individual company accounts. || If your existing password is rejected, use the password-reset link.","password-reset link = recover access without sharing credentials",84,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-MIGRATION"),
      new ToeicQuestion("R-P7-MIGRATION-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Will internal help desk support be available when Melissa plans to log in?",["No, it starts at 8 A.M.","Yes, it begins before 7:30 A.M.","No, it ends at 7 A.M.","Yes, but only by email"],1,
        "帮助台从上午7点开始服务，Melissa计划7:30登录，时间落在服务开始之后。","support begins at 7 A.M. || I also need to log in from my laptop at 7:30 A.M. that day.","support begins before the login attempt = available by that time",83,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-MIGRATION"),
      new ToeicQuestion("R-P7-LICENSE-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why is the requested order eligible for the volume discount?",["It contains exactly ten active-user licenses","The account is being opened in November","The team plans to add two licenses later","A new setup charge applies to it"],0,
        "价格规则规定10个及以上用户许可证享有15%折扣，采购单初始申请恰好10个。","Orders for 10 or more licenses receive a 15 percent discount on license fees only. || We would like to open a new team account with 10 active-user licenses","10 or more = the 10 licenses requested qualify",91,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LICENSE"),
      new ToeicQuestion("R-P7-LICENSE-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is the discounted monthly license charge for the initial order?",["$500","$440","$425","$485"],2,
        "10个许可证每个50美元共500美元，许可证费用享受15%即75美元折扣，因此月费425美元（不含设置费）。","A monthly team license costs $50 per active user. Orders for 10 or more licenses receive a 15 percent discount on license fees only. || 10 active-user licenses beginning December 1.","15 percent off $500 = $425 license fee",93,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LICENSE"),
      new ToeicQuestion("R-P7-LICENSE-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much should the first invoice total before taxes?",["$560","$485","$425","$500"],1,
        "首月许可证425美元再加一次性设置费60美元，合计485美元。采购与财务均确认初始数量为10。","New customer accounts have a one-time setup charge of $60. || 10 active-user licenses beginning December 1. || The first invoice will reflect the volume discount and the one-time setup charge.","first invoice = discounted licenses $425 plus setup $60",98,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LICENSE"),
      new ToeicQuestion("R-P7-LICENSE-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"When is the new team account expected to become active?",["November 3","November 4","January 1","December 1"],3,
        "财务邮件明确可以12月1日激活新账号。","can activate the account on December 1.","activate = begin use of account",49,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LICENSE"),
      new ToeicQuestion("R-P7-LICENSE-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why should the two possible extra users be excluded from the first invoice?",["The manager said not to include them in the initial order","The software cannot support more than ten users","The team must wait for the yearly subscription to end","They have already been paid for by another department"],0,
        "采购明确额外两人可能在1月需要，但不加入初始订单；定价规则说增加许可证在后续账单计费。","Teams may add licenses during the month, but any increase will be billed on the next invoice. || We may need two additional users in January, but please do not add them to the first order.","possible future users ≠ licenses in the first purchase",89,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LICENSE")
    ];
  }
}
