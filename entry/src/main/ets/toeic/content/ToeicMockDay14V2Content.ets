import { ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup, ToeicReviewStatus, ToeicScoreValue, ToeicSection, ToeicSkill } from '../domain/ToeicModels';
import { ToeicWeekTwoContent } from './ToeicWeekTwoContent';

/** Day14 versioned Part7: 10 single passages (29 questions) and five double
 * passages (25 questions). Historical R-M1-* questions are left untouched.
 * Eight single passages and 15 questions in five multi sets reuse source
 * text with NEW question IDs; original unique mock-v2 IDs protect old drafts.
 */
export class ToeicMockDay14V2Content {
  private static splitDocuments(passage:string):string[] {
    let blocks:string[]=[]; let starts:number[]=[0];
    let d2=passage.indexOf('DOCUMENT 2');
    let d3=passage.indexOf('DOCUMENT 3');
    if(d2>0) starts.push(d2);
    if(d3>0) starts.push(d3);
    for(let i=0;i<starts.length;i++) {
      let end=i+1<starts.length?starts[i+1]:passage.length;
      blocks.push(passage.substring(starts[i],end).trim());
    }
    return blocks;
  }

  static questions():ToeicQuestion[] {
    let legacy=ToeicWeekTwoContent.mockQuestions();
    let result:ToeicQuestion[]=[];
    for(let i=0;i<24;i++) {
      let q=legacy[46+i];
      let id='R-FM1-P7-S'+String(Math.floor(i/3)+1).padStart(2,'0')+'-'+String(i%3+1).padStart(2,'0');
      result.push(new ToeicQuestion(id,q.section,q.part,q.skill,q.passage,q.stem,q.options.slice(),q.correctIndex,
        q.explanation,q.evidence,q.paraphrase,q.recommendedSeconds,q.difficulty,q.scoreValue));
    }
    result.push(new ToeicQuestion("R-FM1-P7-S09-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"AFTER-HOURS ACCESS NOTICE\n[1] After 6 P.M., the west lobby entrance is locked. [2] Employees with active staff badges may use the north entrance until 9 P.M. [3] Visitors must call the reception desk before entering and check in with Security. [4] Any temporary badges must be returned before leaving.","Which entrance can badge holders use after 6 P.M.?",["The west lobby","The north entrance","The loading dock","The south garage"],1,"员工晚上可使用北侧入口。","Employees with active staff badges may use the north entrance until 9 P.M.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM1-P7-S09-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"AFTER-HOURS ACCESS NOTICE\n[1] After 6 P.M., the west lobby entrance is locked. [2] Employees with active staff badges may use the north entrance until 9 P.M. [3] Visitors must call the reception desk before entering and check in with Security. [4] Any temporary badges must be returned before leaving.","What must visitors do before entering?",["Pay an access fee","Use the loading dock","Call reception and check in with Security","Return a staff badge"],2,"访客先联系接待处并向安保登记。","Visitors must call the reception desk before entering and check in with Security.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM1-P7-S09-03",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.SENTENCE_LOCATION,"AFTER-HOURS ACCESS NOTICE\n[1] After 6 P.M., the west lobby entrance is locked. [2] Employees with active staff badges may use the north entrance until 9 P.M. [3] Visitors must call the reception desk before entering and check in with Security. [4] Any temporary badges must be returned before leaving.","Where should this sentence be inserted? 'Security will issue a temporary badge to each approved visitor.'",["[1]","[2]","[3]","[4]"],3,"登记后发临时卡，之后说明卡片归还。","Visitors must call the reception desk before entering and check in with Security. [4] Any temporary badges must be returned before leaving.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM1-P7-S10-01",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"COURSE REGISTRATION NOTICE\nThe October 21 project-planning workshop is limited to 24 participants. Online registration closes at 5 P.M. on October 15. Employees who receive confirmation must bring a laptop with the spreadsheet template already installed. A waiting list will open if the class fills.","By when must employees register for the workshop?",["At 5 P.M. on October 15","On October 21","At noon on October 15","On October 24"],0,"截止日期是10月15日下午5点。","Online registration closes at 5 P.M. on October 15.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    result.push(new ToeicQuestion("R-FM1-P7-S10-02",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"COURSE REGISTRATION NOTICE\nThe October 21 project-planning workshop is limited to 24 participants. Online registration closes at 5 P.M. on October 15. Employees who receive confirmation must bring a laptop with the spreadsheet template already installed. A waiting list will open if the class fills.","What should confirmed participants bring?",["A printed invoice","An external monitor","A signed travel claim","A laptop with the template installed"],3,"需携带装有表格模板的笔记本电脑。","Employees who receive confirmation must bring a laptop with the spreadsheet template already installed.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,""));
    // The five original two-document passages each had three questions.
    // Copy those questions under new IDs and re-ground evidence to verbatim
    // fragments in the linked documents. Rotate the option order to prevent
    // position-based guessing inside each five-question passage.
    let evidence:string[][]=[["Train 52: Easton 7:50 → Central 8:35 || Our presentation at Central Tower starts at 9:15.","Please allow 20 minutes to walk from the station.","Train 60: Easton 8:20 → Central 9:05 || Our presentation at Central Tower starts at 9:15."],["Spend $80 or more online and receive free standard delivery. || My cart total is $92.","My cart total is $92.","I do not need express shipping."],["Amount due: $640 || Payments received after the due date are subject to a $25 late fee.","subject to a $25 late fee.","Bank transfers may take up to two business days to post."],["Route 7 arrives Downtown at 8:40 and 9:10. || The team meeting begins at 9:00 in the Downtown office.","It takes about 10 minutes to walk from the bus stop.","The team meeting begins at 9:00 in the Downtown office."],["one year of office experience required || I have worked as an office coordinator since June last year","applications due Nov. 10.","start date Dec. 1 || can start November 25."]];
    for(let group=0;group<5;group++) {
      for(let item=0;item<3;item++) {
        let original=legacy[70+group*3+item];
        let options:string[]=[];
        for(let o=0;o<4;o++) options.push(original.options[(o+4-item)%4]);
        result.push(new ToeicQuestion(
          'R-FM1-P7-M'+String(group+1)+'-'+String(item+1).padStart(2,'0'),
          original.section,original.part,original.skill,'',original.stem,options,
          (original.correctIndex+item)%4,original.explanation,evidence[group][item],
          original.paraphrase,original.recommendedSeconds,original.difficulty,
          original.scoreValue,ToeicReviewStatus.PUBLISHED,1,'','',0,0,'FM1-G'+String(group+1)));
      }
    }
    result.push(new ToeicQuestion("R-FM1-P7-M1-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What event is scheduled to begin at 9:15?",["A training seminar","A hotel check-in","A supplier call","A presentation"],3,"9:15开始的是演示汇报。","Our presentation at Central Tower starts at 9:15.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G1"));
    result.push(new ToeicQuestion("R-FM1-P7-M1-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","At which station does Train 52 arrive at 8:35?",["Easton","Central","Northgate","Union Park"],1,"列车52于8:35到达Central。","Train 52: Easton 7:50 → Central 8:35",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G1"));
    result.push(new ToeicQuestion("R-FM1-P7-M2-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","When does the free-delivery offer end?",["October 28","November 1","September 30","October 31"],3,"优惠截至10月31日。","Offer ends October 31.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G2"));
    result.push(new ToeicQuestion("R-FM1-P7-M2-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","On what date was the customer email sent?",["October 31","October 28","October 20","November 28"],1,"邮件日期是10月28日。","CUSTOMER E-MAIL dated October 28",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G2"));
    result.push(new ToeicQuestion("R-FM1-P7-M3-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","When must invoice 3118 be paid?",["November 7","November 5","October 31","November 6"],3,"付款截止日为11月6日。","Due date: Nov. 6",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G3"));
    result.push(new ToeicQuestion("R-FM1-P7-M3-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","What payment method may take two business days to post?",["Credit-card payment","Bank transfer","Cash at reception","Mobile wallet"],1,"银行转账可能需要两个工作日入账。","Bank transfers may take up to two business days to post.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G3"));
    result.push(new ToeicQuestion("R-FM1-P7-M4-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","Where will the team meeting be held?",["At the bus station","At Easton","At the training center","At the Downtown office"],3,"会议地点是Downtown办公室。","The team meeting begins at 9:00 in the Downtown office.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G4"));
    result.push(new ToeicQuestion("R-FM1-P7-M4-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.CROSS_DOCUMENT,"","At what time would someone taking the 8:40 bus arrival reach the office after the stated walk?",["8:40","8:50","9:00","9:10"],1,"8:40到站加10分钟步行即8:50。","Route 7 arrives Downtown at 8:40 and 9:10. || It takes about 10 minutes to walk from the bus stop.",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G4"));
    result.push(new ToeicQuestion("R-FM1-P7-M5-04",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","When is the marketing assistant position scheduled to begin?",["November 8","November 10","November 25","December 1"],3,"职位计划12月1日开始。","start date Dec. 1",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G5"));
    result.push(new ToeicQuestion("R-FM1-P7-M5-05",ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,"","When was the applicant's email written?",["November 10","November 8","November 25","December 1"],1,"申请邮件写于11月8日。","APPLICANT E-MAIL dated Nov. 8",'',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL,ToeicReviewStatus.PUBLISHED,1,'','',0,0,"FM1-G5"));
    return result;
  }

  static groups():ToeicReadingGroup[] {
    let legacy=ToeicWeekTwoContent.mockQuestions();
    let result:ToeicReadingGroup[]=[];
    for(let group=0;group<5;group++) {
      let ids:string[]=[];
      for(let q=1;q<=5;q++) ids.push('R-FM1-P7-M'+String(group+1)+'-'+String(q).padStart(2,'0'));
      result.push(new ToeicReadingGroup('FM1-G'+String(group+1),ids,
        ToeicMockDay14V2Content.splitDocuments(legacy[70+group*3].passage)));
    }
    return result;
  }
}
