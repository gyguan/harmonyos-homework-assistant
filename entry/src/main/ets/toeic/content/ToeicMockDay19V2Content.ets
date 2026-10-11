import { ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup, ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill } from '../domain/ToeicModels';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';

/** Day19 v2 paper: 10 single passages (29 questions), five multi-document
 * passages (25 questions). The original R-M2-* collection remains addressable
 * by historic drafts and saved reports. New IDs are stable and versioned.
 */
export class ToeicMockDay19V2Content {
  private static splitDocuments(passage:string,group:number):string[] {
    let markers:string[][]=[["\n\nMESSAGE"],["\n\nRECEIPT","\n\nNOTE"],["\n\nE-MAIL"],["\n\nRECEIPT","\n\nSUPPORT NOTE"],["\n\nRÉSUMÉ","\n\nE-MAIL"]];
    let offsets:number[]=[0];
    for(let token of markers[group]) {
      let index=passage.indexOf(token);
      if(index>0) offsets.push(index+2);
    }
    let result:string[]=[];
    for(let i=0;i<offsets.length;i++) {
      let end=i+1<offsets.length?offsets[i+1]:passage.length;
      result.push(passage.substring(offsets[i],end).trim());
    }
    return result;
  }
  static questions():ToeicQuestion[] {
    let legacy=ToeicWeekThreeContent.mockQuestions();
    let result:ToeicQuestion[]=[];
    // The first six legacy Part7 passages were single documents (18 items).
    for(let i=0;i<18;i++) {
      let old=legacy[46+i];
      let id='R-FM2-P7-S'+String(Math.floor(i/3)+1).padStart(2,'0')+'-'+String(i%3+1).padStart(2,'0');
      result.push(new ToeicQuestion(id,old.section,old.part,old.skill,old.passage,
        old.stem,old.options.slice(),old.correctIndex,old.explanation,old.evidence,
        old.paraphrase,old.recommendedSeconds,old.difficulty,old.scoreValue));
    }
    result.push(new ToeicQuestion("R-FM2-P7-S07-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"PRODUCT SAFETY UPDATE\n[1] Production of the Model R desk lamp is temporarily paused while the power adapter is inspected. [2] Customers who bought the lamp after May 1 should contact the service desk with their receipt number. [3] The service desk will arrange collection of eligible units at no charge. [4] Replacement adapters will be sent within five working days after the lamps are checked.","Why was production of the desk lamp paused?",["A supplier raised prices","Adapters require inspection","A new color was introduced","Demand declined"],1,"暂停生产是为了检查电源适配器。","Production of the Model R desk lamp is temporarily paused while the power adapter is inspected.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S07-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"PRODUCT SAFETY UPDATE\n[1] Production of the Model R desk lamp is temporarily paused while the power adapter is inspected. [2] Customers who bought the lamp after May 1 should contact the service desk with their receipt number. [3] The service desk will arrange collection of eligible units at no charge. [4] Replacement adapters will be sent within five working days after the lamps are checked.","What must eligible customers provide?",["A copy of the warranty policy","An installation photo","Their receipt number","A shipping label"],2,"需提供收据编号。","contact the service desk with their receipt number.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S07-03",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.SENTENCE_LOCATION,"PRODUCT SAFETY UPDATE\n[1] Production of the Model R desk lamp is temporarily paused while the power adapter is inspected. [2] Customers who bought the lamp after May 1 should contact the service desk with their receipt number. [3] The service desk will arrange collection of eligible units at no charge. [4] Replacement adapters will be sent within five working days after the lamps are checked.","Where best insert: 'Customers will be contacted to arrange a convenient pickup time.'",["[1]","[2]","[3]","[4]"],3,"回收安排后紧接具体联系取件时间，再说更换发货。","The service desk will arrange collection of eligible units at no charge. [4] Replacement adapters will be sent",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S08-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"EMPLOYEE BENEFITS NOTICE\nStarting January 1, staff who have worked at the company for at least six months can claim up to $120 annually for approved professional books. Claims must include the original purchase receipt and be submitted through the employee portal by December 15. Unused allowances do not carry into the following year.","Who is eligible for the professional-book allowance?",["All temporary visitors","Only department managers","Employees with at least six months of service","Only new hires"],2,"须任职至少六个月。","staff who have worked at the company for at least six months",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S08-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"EMPLOYEE BENEFITS NOTICE\nStarting January 1, staff who have worked at the company for at least six months can claim up to $120 annually for approved professional books. Claims must include the original purchase receipt and be submitted through the employee portal by December 15. Unused allowances do not carry into the following year.","What must accompany an allowance claim?",["A course certificate","An original purchase receipt","A travel approval","A library card"],1,"报销需原始购买收据。","Claims must include the original purchase receipt",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S08-03",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"EMPLOYEE BENEFITS NOTICE\nStarting January 1, staff who have worked at the company for at least six months can claim up to $120 annually for approved professional books. Claims must include the original purchase receipt and be submitted through the employee portal by December 15. Unused allowances do not carry into the following year.","What happens to any unused annual allowance?",["It is refunded in cash","It doubles next year","It can be transferred to another employee","It does not carry over"],3,"未使用金额不能结转下一年。","Unused allowances do not carry into the following year.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S09-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"CUSTOMER SUPPORT CHAT\n09:12 — Customer: The wireless headset I ordered arrived without a charging cable.\n09:14 — Support: I am sorry about that. Please provide order number 5824 in the support form. We will ship the missing cable at no cost by express post tomorrow.\n09:16 — Customer: Thank you. The headset itself works normally, so I do not need a replacement unit.","What problem does the customer report?",["A missing charging cable","A damaged headset","A late invoice","An incorrect billing address"],0,"缺少充电线。","arrived without a charging cable.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S09-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"CUSTOMER SUPPORT CHAT\n09:12 — Customer: The wireless headset I ordered arrived without a charging cable.\n09:14 — Support: I am sorry about that. Please provide order number 5824 in the support form. We will ship the missing cable at no cost by express post tomorrow.\n09:16 — Customer: Thank you. The headset itself works normally, so I do not need a replacement unit.","How will Support send the missing part?",["By ordinary surface mail","With the next headset order","By express post","Through in-store pickup"],2,"将免费使用加急邮寄。","ship the missing cable at no cost by express post tomorrow.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S09-03",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"CUSTOMER SUPPORT CHAT\n09:12 — Customer: The wireless headset I ordered arrived without a charging cable.\n09:14 — Support: I am sorry about that. Please provide order number 5824 in the support form. We will ship the missing cable at no cost by express post tomorrow.\n09:16 — Customer: Thank you. The headset itself works normally, so I do not need a replacement unit.","Why is a replacement headset unnecessary?",["The customer canceled the order","The store is closed","The order has already been refunded","The headset itself works normally"],3,"耳机主机工作正常，无需更换。","The headset itself works normally, so I do not need a replacement unit.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S10-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"DELIVERY OPERATIONS NOTICE\nThe central warehouse will change its truck dispatch time from 4 P.M. to 3:30 P.M. beginning June 8. Orders entered after 2 P.M. will be scheduled for the next business day. Drivers should collect revised route sheets at the dispatch office before departure.","When will the new dispatch time take effect?",["June 7","June 8","June 18","July 8"],1,"新时间6月8日起生效。","beginning June 8.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM2-P7-S10-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"DELIVERY OPERATIONS NOTICE\nThe central warehouse will change its truck dispatch time from 4 P.M. to 3:30 P.M. beginning June 8. Orders entered after 2 P.M. will be scheduled for the next business day. Drivers should collect revised route sheets at the dispatch office before departure.","What should drivers collect before leaving?",["New uniforms","Fuel vouchers","Purchase receipts","Revised route sheets"],3,"司机出发前领取更新路线单。","Drivers should collect revised route sheets at the dispatch office before departure.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    // Clone the legacy G–K passage items with new IDs and verbatim citations.
    // Rotation is on the authored copy only; the legacy source is untouched.
    let evidence:string[][]=[["88: Bayview 7:40 → Central 8:35 || Our client briefing at Central Plaza starts at 9:15.","94: Bayview 8:05 → Central 9:00","Our client briefing at Central Plaza starts at 9:15."],["20% off one office chair. || Office chair $150","August 28 — Office chair $150","Valid through August 31. || August 28 — Office chair $150"],["Parking at the venue costs $12. || I will take the company shuttle","I selected the vegetarian lunch option when I registered.","Leadership Forum — November 5, 9 A.M.–3 P.M."],["covered for one year from purchase || Scanner purchased March 12.","Damage caused by dropping or water is excluded. || No visible impact or water damage.","Unit no longer powers on."],["available to start by September 15. || I can begin on September 8 if selected.","minimum two years of logistics experience || three years in warehouse logistics","minimum two years of logistics experience || three years in warehouse logistics"]];
    for(let group=0;group<5;group++) {
      for(let item=0;item<3;item++) {
        let old=legacy[64+group*3+item];
        let rotation=(item-old.correctIndex+4)%4;
        let choices:string[]=[];
        for(let c=0;c<4;c++) choices.push(old.options[(c+4-rotation)%4]);
        result.push(new ToeicQuestion(
          'R-FM2-P7-M'+String(group+1)+'-'+String(item+1).padStart(2,'0'),
          old.section,old.part,old.skill,'',old.stem,choices,item,old.explanation,
          evidence[group][item],old.paraphrase,old.recommendedSeconds,old.difficulty,
          old.scoreValue,ToeicReviewStatus.PUBLISHED,1,'','',0,0,'FM2-G'+String(group+1)));
      }
    }
    result.push(new ToeicQuestion("R-FM2-P7-M1-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","At what time does Train 102 arrive at Central?",["9:00","8:35","7:40","9:25"],3,"102次列车9:25到达Central。","102: Bayview 8:30 → Central 9:25",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G1"));
    result.push(new ToeicQuestion("R-FM2-P7-M1-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","How much time before the briefing does the message request?",["10 minutes","20 minutes","30 minutes","45 minutes"],1,"需要至少提前20分钟到站。","Please arrive at Central Station at least 20 minutes before the meeting",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G1"));
    result.push(new ToeicQuestion("R-FM2-P7-M2-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","Which product is eligible for the coupon?",["A desk organizer","A printer","A standing desk","An office chair"],3,"优惠适用于办公椅。","20% off one office chair.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G2"));
    result.push(new ToeicQuestion("R-FM2-P7-M2-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","Can the coupon be combined with another discount?",["Yes, for all products","No, the conditions prohibit it","Yes, on weekends only","Only when purchasing two chairs"],1,"优惠券不能与其他折扣叠加。","Cannot be combined with other discounts.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G2"));
    result.push(new ToeicQuestion("R-FM2-P7-M3-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","On what date will the Leadership Forum be held?",["November 3","November 10","November 6","November 5"],3,"论坛于11月5日举行。","Leadership Forum — November 5",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G3"));
    result.push(new ToeicQuestion("R-FM2-P7-M3-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What is the venue's parking fee?",["$10","$12","$20","Parking is free"],1,"停车费为12美元。","Parking at the venue costs $12.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G3"));
    result.push(new ToeicQuestion("R-FM2-P7-M4-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","When was the scanner originally purchased?",["February 20","April 12","May 12","March 12"],3,"收据日期为3月12日。","Scanner purchased March 12.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G4"));
    result.push(new ToeicQuestion("R-FM2-P7-M4-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What kind of damage is excluded from warranty coverage?",["Manufacturing defects","Damage caused by dropping or water","Failure to power on without damage","A defective internal component"],1,"跌落或进水损坏不在保修范围。","Damage caused by dropping or water is excluded.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G4"));
    result.push(new ToeicQuestion("R-FM2-P7-M5-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What spreadsheet qualification does Dario list?",["Basic orientation attendance","A manager recommendation","No spreadsheet experience","An advanced spreadsheet certification"],3,"简历列明高级电子表格认证。","advanced spreadsheet certification.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G5"));
    result.push(new ToeicQuestion("R-FM2-P7-M5-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What position is advertised?",["Operations Coordinator","Sales Assistant","Warehouse Driver","Marketing Intern"],0,"招聘职位是运营协调员。","Operations Coordinator: minimum two years of logistics experience",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM2-G5"));
    return result;
  }
  static groups():ToeicReadingGroup[] {
    let legacy=ToeicWeekThreeContent.mockQuestions();
    let result:ToeicReadingGroup[]=[];
    for(let group=0;group<5;group++) {
      let ids:string[]=[];
      for(let q=1;q<=5;q++) ids.push('R-FM2-P7-M'+String(group+1)+'-'+String(q).padStart(2,'0'));
      // Preserve historical v1 ID while publishing fully evidenced active revision.
      if (group===0 || group===4) ids.push('R-FM2-P7-M'+String(group+1)+'-06');
      result.push(new ToeicReadingGroup('FM2-G'+String(group+1),ids,
        ToeicMockDay19V2Content.splitDocuments(legacy[64+group*3].passage,group)));
    }
    return result;
  }
}
