import { ToeicReviewStatus, ToeicVocabularyItem, ToeicVocabularyLevel } from '../domain/ToeicModels';

/** Original property, policy and finance vocabulary; remains REVIEWED pending human signoff. */
export class ToeicVocabularyBatchFive {
  static items():ToeicVocabularyItem[] {
    return [
      new ToeicVocabularyItem("V-211","tenant","n.","租户；承租人",ToeicVocabularyLevel.L2,"物业",["commercial tenant"],["renter"],"","en-US","","The tenant asked the property manager to repair the heating system.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-212","landlord","n.","房东；出租人",ToeicVocabularyLevel.L2,"物业",["commercial landlord"],["property owner"],"","en-US","","The landlord approved the request to repaint the office.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-213","premises","n. pl.","房屋；经营场所",ToeicVocabularyLevel.L3,"物业",["business premises"],["building or site"],"","en-US","","Visitors must sign in before entering the premises.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-214","occupancy","n.","入住；使用率",ToeicVocabularyLevel.L3,"酒店",["occupancy rate"],["room utilization"],"","en-US","","The hotel reported an occupancy rate of eighty percent.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-215","utilities","n. pl.","水电燃气等公共事业费用",ToeicVocabularyLevel.L2,"物业",["monthly utilities"],["water and electricity services"],"","en-US","","Utilities are billed separately from the office rent.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-216","fixture","n.","固定装置；附属设备",ToeicVocabularyLevel.L3,"设施",["lighting fixture"],["permanently attached fitting"],"","en-US","","The contractor replaced a damaged lighting fixture.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-217","permit","n.","许可证；许可文件",ToeicVocabularyLevel.L2,"合规",["building permit"],["official authorization document"],"","en-US","","Construction cannot begin until the city issues a permit.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-218","deposit","n.","押金；订金",ToeicVocabularyLevel.L2,"酒店",["refundable deposit"],["advance payment"],"","en-US","","A refundable deposit is required to reserve the meeting space.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-219","amendment","n.","修正案；合同修订",ToeicVocabularyLevel.L3,"合同",["contract amendment"],["formal change"],"","en-US","","Both parties signed an amendment to the rental agreement.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-220","terminate","v.","终止；结束合同",ToeicVocabularyLevel.L3,"合同",["terminate an agreement"],["end formally"],"","en-US","","Either party may terminate the agreement with thirty days' notice.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-221","disclosure","n.","披露；公开说明",ToeicVocabularyLevel.L3,"合规",["financial disclosure"],["release of information"],"","en-US","","The application requires disclosure of potential conflicts of interest.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-222","liability","n.","法律责任；负债",ToeicVocabularyLevel.L3,"合同",["limited liability"],["legal responsibility"],"","en-US","","The policy limits the supplier's liability for shipping delays.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-223","coverage","n.","保险保障范围；覆盖",ToeicVocabularyLevel.L2,"保险",["insurance coverage"],["scope of protection"],"","en-US","","The basic insurance plan includes dental coverage.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-224","premium","n.","保险费；保费",ToeicVocabularyLevel.L3,"保险",["monthly premium"],["insurance payment"],"","en-US","","The annual premium will increase when the policy is renewed.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-225","beneficiary","n.","受益人",ToeicVocabularyLevel.L3,"保险",["designated beneficiary"],["person receiving benefits"],"","en-US","","Employees must name a beneficiary on the enrollment form.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-226","broker","n.","经纪人；中介",ToeicVocabularyLevel.L2,"房产",["real estate broker"],["intermediary"],"","en-US","","The broker arranged three tours of commercial properties.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-227","appraisal","n.","评估；估价",ToeicVocabularyLevel.L3,"房产",["property appraisal"],["professional valuation"],"","en-US","","The bank requested a property appraisal before approving the loan.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-228","valuation","n.","估值；价值评估",ToeicVocabularyLevel.L3,"财务",["asset valuation"],["assessment of worth"],"","en-US","","The report includes an independent valuation of the equipment.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-229","collateral","n.","抵押品；担保物",ToeicVocabularyLevel.L3,"财务",["provide collateral"],["pledged security"],"","en-US","","The lender required collateral for the business loan.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-230","mortgage","n.","抵押贷款",ToeicVocabularyLevel.L3,"财务",["mortgage payment"],["property loan"],"","en-US","","The company refinanced the mortgage on its headquarters.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-231","provisional","adj.","临时的；暂定的",ToeicVocabularyLevel.L3,"审批",["provisional approval"],["temporary"],"","en-US","","The committee granted provisional approval pending the final review.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-232","exemption","n.","豁免；免除",ToeicVocabularyLevel.L3,"合规",["tax exemption"],["exception from requirement"],"","en-US","","The nonprofit organization applied for a tax exemption.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-233","waiver","n.","豁免；弃权声明",ToeicVocabularyLevel.L3,"合同",["fee waiver"],["formal exemption"],"","en-US","","Students may request a fee waiver under certain conditions.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-234","stipulate","v.","明确规定；约定",ToeicVocabularyLevel.L3,"合同",["contract stipulates"],["specify"],"","en-US","","The agreement stipulates that payment is due within fifteen days.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-235","convey","v.","传达；表达",ToeicVocabularyLevel.L3,"沟通",["convey information"],["communicate"],"","en-US","","The manager asked the assistant to convey the schedule changes.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-236","endorsement","n.","背书；认可",ToeicVocabularyLevel.L3,"营销",["product endorsement"],["public support"],"","en-US","","The campaign received an endorsement from a professional association.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-237","sublet","v.","转租；分租",ToeicVocabularyLevel.L3,"物业",["sublet office space"],["rent to another tenant"],"","en-US","","The tenant needs written permission to sublet part of the office.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-238","arrears","n. pl.","欠款；逾期未付款项",ToeicVocabularyLevel.L3,"财务",["rent in arrears"],["overdue payments"],"","en-US","","The notice stated that two months of rent were in arrears.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-239","disbursement","n.","拨付；支出款项",ToeicVocabularyLevel.L3,"财务",["loan disbursement"],["release of funds"],"","en-US","","The finance team scheduled the loan disbursement for Monday.",ToeicReviewStatus.REVIEWED),
      new ToeicVocabularyItem("V-240","commission","n.","佣金；提成",ToeicVocabularyLevel.L2,"销售",["sales commission"],["percentage paid for sales"],"","en-US","","The sales commission is paid at the end of each quarter.",ToeicReviewStatus.REVIEWED)
    ];
  }

  static idsForDay(day:number):string[] {
    if (day<2 || day>13) return [];
    let start=Math.floor((day-2)*30/12);
    let end=Math.floor((day-1)*30/12);
    let ids:string[]=[];
    for (let index=start;index<end;index++) ids.push('V-'+String(211+index));
    return ids;
  }
}
