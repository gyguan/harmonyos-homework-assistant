import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup,
  ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill
} from '../domain/ToeicModels';

/** Original extra cross-document practice. Each item requires independent editorial signoff. */
export class ToeicExtraReadingBatchFour {
  static groups():ToeicReadingGroup[] {
    return [
      new ToeicReadingGroup("P7-EX-LEASE",["R-P7-LEASE-01","R-P7-LEASE-02","R-P7-LEASE-03","R-P7-LEASE-04","R-P7-LEASE-05"],["DOCUMENT 1 — TEMPORARY OFFICE SUITE AGREEMENT\nNorth Plaza leases Suite C for $900 per month through August 31. The refundable security deposit is $300. Furniture deliveries are permitted Monday through Friday between 9 A.M. and 5 P.M. An extension of the rental period requires the property manager's written approval, and the existing deposit carries forward if the same tenant remains in the suite.","DOCUMENT 2 — EMAIL, AUGUST 3\nTo: North Plaza Property Office\nWe would like to keep Suite C for September because our client presentations have been moved to September 18. Please let us know the extension procedure. We also plan to move additional furniture into the suite on Thursday, September 3, at 8 A.M. Can our movers enter at that time?\n— Iris, Meridian Consulting","DOCUMENT 3 — PROPERTY OFFICE RESPONSE, AUGUST 4\nTo: Iris\nWe can extend the rental through September 30 if the agreement is signed by August 15. September rent will remain $900, and no new security deposit is required. However, please schedule furniture delivery no earlier than 9 A.M. on a weekday. We can email the extension form today."]),
      new ToeicReadingGroup("P7-EX-TRAINING",["R-P7-TRAINING-01","R-P7-TRAINING-02","R-P7-TRAINING-03","R-P7-TRAINING-04","R-P7-TRAINING-05"],["DOCUMENT 1 — EMPLOYEE CERTIFICATION SUPPORT POLICY\nThe company reimburses up to $300 for approved professional-course tuition when the employee completes the course and earns at least 75 percent on the final assessment. Applications must include an itemized tuition receipt and the completion result and must be submitted within 10 calendar days after course completion. Transportation and textbooks are not eligible expenses.","DOCUMENT 2 — EMPLOYEE CLAIM MESSAGE, JUNE 2\nTo: Learning and Development\nI completed the approved project-management course on May 23 and scored 88 percent on the final assessment. Attached are the completion result and an itemized tuition receipt for $260. I also purchased a $45 textbook and paid $22 for local transportation. Can you confirm the amount I should claim before I submit the form today?\n— Daniel Chen"])
    ];
  }

  static questions():ToeicQuestion[] {
    return [
      new ToeicQuestion("R-P7-LEASE-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.PURPOSE,'',"Why did Iris contact the property office?",["To ask for a deposit refund","To request more time in Suite C","To complain about the rental price","To report furniture damage"],1,
        "邮件说明客户展示调整至9月，租户希望续租Suite C并询问手续。","We would like to keep Suite C for September","keep the suite for September = extend a lease",65,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LEASE"),
      new ToeicQuestion("R-P7-LEASE-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What monthly rent should Meridian Consulting expect for September?",["$300","$600","$900","$1,200"],2,
        "原租约月租900美元，物业回复明确9月继续按900美元收费。","leases Suite C for $900 per month || September rent will remain $900","remain $900 = unchanged monthly rent",85,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LEASE"),
      new ToeicQuestion("R-P7-LEASE-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"What is the earliest time the movers can enter on the proposed Thursday?",["9 A.M.","8 A.M.","5 P.M.","7 A.M."],0,
        "租约允许工作日9点起收货，物业明确否定8点并要求不早于9点。","Furniture deliveries are permitted Monday through Friday between 9 A.M. and 5 P.M. || please schedule furniture delivery no earlier than 9 A.M.","no earlier than 9 A.M. = at or after 9 A.M.",90,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LEASE"),
      new ToeicQuestion("R-P7-LEASE-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"By when must the extension agreement be signed?",["August 3","August 4","September 18","August 15"],3,
        "物业回复写明8月15日前签署续租协议。","if the agreement is signed by August 15","signed by = signed no later than",51,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LEASE"),
      new ToeicQuestion("R-P7-LEASE-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why will the property office not request a second deposit?",["The initial deposit was forfeited","The same tenant will continue using the suite","The September rent was waived","The furniture delivery was canceled"],1,
        "租约规定同一租户续租则原押金结转，而邮件说明 Meridian 继续使用相同办公室。","the existing deposit carries forward if the same tenant remains in the suite || We would like to keep Suite C for September","deposit carries forward = original security amount remains on file",94,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-LEASE"),
      new ToeicQuestion("R-P7-TRAINING-01",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"How much may Daniel claim under the stated reimbursement policy?",["$260","$300","$327","$305"],0,
        "政策仅报销符合条件的课程学费且最高300美元，Daniel 的学费为260美元。","reimburses up to $300 for approved professional-course tuition || an itemized tuition receipt for $260","eligible course tuition = $260",90,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAINING"),
      new ToeicQuestion("R-P7-TRAINING-02",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Does Daniel meet the assessment-score requirement?",["No, because he scored under 90 percent","No, because the course was not approved","Yes, because 88 percent exceeds the required 75 percent","Yes, because the score requirement applies only to textbooks"],2,
        "政策规定最低75%，邮件中 Daniel 的考核成绩是88%。","earns at least 75 percent on the final assessment || scored 88 percent on the final assessment","at least 75 percent = a score of 75 percent or higher",82,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAINING"),
      new ToeicQuestion("R-P7-TRAINING-03",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.DETAIL,'',"Which supporting materials did Daniel attach?",["A transit ticket and a textbook receipt","The course brochure and a travel invoice","A registration form and a manager's letter","A completion result and an itemized tuition receipt"],3,
        "邮件明确附上结业成绩和逐项学费收据。","Attached are the completion result and an itemized tuition receipt for $260.","supporting materials = evidence required by the policy",55,
        ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAINING"),
      new ToeicQuestion("R-P7-TRAINING-04",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Is Daniel submitting the request within the allowed period?",["No, the limit is seven days","Yes, June 2 is ten calendar days after May 23","No, only same-day applications are accepted","Yes, but only because the course was free"],1,
        "课程结束时间是5月23日，政策期限为结束后10个自然日，6月2日处于截止日。","within 10 calendar days after course completion || I completed the approved project-management course on May 23 || EMPLOYEE CLAIM MESSAGE, JUNE 2","ten calendar days after May 23 = June 2",96,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAINING"),
      new ToeicQuestion("R-P7-TRAINING-05",ToeicSection.READING,ToeicPart.PART_7,
        ToeicSkill.CROSS_DOCUMENT,'',"Why should Daniel exclude the textbook from his claim?",["It cost less than the tuition fee","The retailer did not issue a receipt","The policy specifically excludes textbooks","Textbooks require a score of 90 percent"],2,
        "政策明确不报销教材费用，而邮件显示购买了45美元教材。","Transportation and textbooks are not eligible expenses. || I also purchased a $45 textbook","not eligible = excluded from reimbursement",83,
        ToeicDifficulty.HARD,ToeicScoreValue.NORMAL,
        ToeicReviewStatus.REVIEWED,1,'','',0,0,"P7-EX-TRAINING")
    ];
  }
}
