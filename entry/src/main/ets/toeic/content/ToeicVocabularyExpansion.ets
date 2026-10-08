import { ToeicVocabularyItem, ToeicVocabularyLevel } from '../domain/ToeicModels';

/**
 * Incremental original business vocabulary, retained as standalone content so
 * high-stakes pronunciation and example corrections do not affect existing V-001..V-090 IDs.
 * IPA is supplied by ToeicPronunciationCatalog.
 */
export class ToeicVocabularyExpansion {
  static items():ToeicVocabularyItem[] {
    return [
      new ToeicVocabularyItem("V-091","approval","n.","批准；认可",ToeicVocabularyLevel.L1,"审批",["obtain approval"],["authorization"],"","en-US","","The purchase request requires the director's approval."),
      new ToeicVocabularyItem("V-092","authorize","v.","授权；批准",ToeicVocabularyLevel.L2,"审批",["authorize a payment"],["approve"],"","en-US","","Only managers may authorize expenses above the limit."),
      new ToeicVocabularyItem("V-093","revise","v.","修订；修改",ToeicVocabularyLevel.L2,"文档",["revise the schedule"],["update"],"","en-US","","The team will revise the delivery schedule."),
      new ToeicVocabularyItem("V-094","amend","v.","修订；修正",ToeicVocabularyLevel.L2,"合同",["amend the contract"],["modify"],"","en-US","","Both parties agreed to amend the contract."),
      new ToeicVocabularyItem("V-095","verify","v.","核实；确认",ToeicVocabularyLevel.L1,"质量",["verify the information"],["check"],"","en-US","","Please verify the account details before submitting the form."),
      new ToeicVocabularyItem("V-096","compliance","n.","合规；遵守",ToeicVocabularyLevel.L2,"治理",["ensure compliance"],["adherence"],"","en-US","","The audit team monitors compliance with company policy."),
      new ToeicVocabularyItem("V-097","confidential","adj.","保密的；机密的",ToeicVocabularyLevel.L2,"治理",["confidential information"],["private"],"","en-US","","Keep all client information confidential."),
      new ToeicVocabularyItem("V-098","mandatory","adj.","强制的；必修的",ToeicVocabularyLevel.L1,"培训",["mandatory training"],["required"],"","en-US","","Safety training is mandatory for new employees."),
      new ToeicVocabularyItem("V-099","policy","n.","政策；规定",ToeicVocabularyLevel.L1,"治理",["company policy"],["rule"],"","en-US","","The updated travel policy takes effect next Monday."),
      new ToeicVocabularyItem("V-100","procedure","n.","程序；流程",ToeicVocabularyLevel.L1,"运营",["follow the procedure"],["process"],"","en-US","","Staff should follow the revised safety procedure."),
      new ToeicVocabularyItem("V-101","implement","v.","实施；执行",ToeicVocabularyLevel.L2,"项目",["implement a plan"],["carry out"],"","en-US","","The company will implement the changes in November."),
      new ToeicVocabularyItem("V-102","allocate","v.","分配；划拨",ToeicVocabularyLevel.L2,"预算",["allocate resources"],["assign"],"","en-US","","The manager will allocate funds to urgent repairs."),
      new ToeicVocabularyItem("V-103","sufficient","adj.","充足的；足够的",ToeicVocabularyLevel.L2,"项目",["sufficient time"],["enough"],"","en-US","","There is sufficient time to finish the installation."),
      new ToeicVocabularyItem("V-104","shortage","n.","短缺；不足",ToeicVocabularyLevel.L2,"物流",["a supply shortage"],["lack"],"","en-US","","A temporary parts shortage delayed production."),
      new ToeicVocabularyItem("V-105","quotation","n.","报价单；报价",ToeicVocabularyLevel.L2,"采购",["request a quotation"],["price estimate"],"","en-US","","Please send us a quotation for twenty desks."),
      new ToeicVocabularyItem("V-106","negotiate","v.","谈判；协商",ToeicVocabularyLevel.L2,"采购",["negotiate a price"],["discuss terms"],"","en-US","","The buyer will negotiate a lower shipping rate."),
      new ToeicVocabularyItem("V-107","warranty","n.","保修；保修期",ToeicVocabularyLevel.L1,"售后",["under warranty"],["guarantee"],"","en-US","","The printer is still under warranty."),
      new ToeicVocabularyItem("V-108","defect","n.","缺陷；瑕疵",ToeicVocabularyLevel.L2,"质量",["a manufacturing defect"],["flaw"],"","en-US","","The inspection revealed a minor defect in the device."),
      new ToeicVocabularyItem("V-109","manufacturer","n.","制造商；生产商",ToeicVocabularyLevel.L2,"制造",["contact the manufacturer"],["producer"],"","en-US","","The manufacturer issued new maintenance instructions."),
      new ToeicVocabularyItem("V-110","distribute","v.","分发；分配",ToeicVocabularyLevel.L2,"物流",["distribute the materials"],["hand out"],"","en-US","","The coordinator will distribute the meeting materials."),
      new ToeicVocabularyItem("V-111","installation","n.","安装；装设",ToeicVocabularyLevel.L1,"设施",["complete the installation"],["setup"],"","en-US","","Installation of the new equipment begins on Friday."),
      new ToeicVocabularyItem("V-112","inspection","n.","检查；检验",ToeicVocabularyLevel.L1,"质量",["pass an inspection"],["examination"],"","en-US","","The building passed its annual safety inspection."),
      new ToeicVocabularyItem("V-113","renewal","n.","续订；续期",ToeicVocabularyLevel.L2,"客户服务",["contract renewal"],["extension"],"","en-US","","Members will receive a renewal notice by email."),
      new ToeicVocabularyItem("V-114","overdue","adj.","逾期的；过期未付的",ToeicVocabularyLevel.L2,"财务",["overdue payment"],["late"],"","en-US","","The accounts team sent reminders about overdue invoices."),
      new ToeicVocabularyItem("V-115","outstanding","adj.","未结清的；尚未支付的",ToeicVocabularyLevel.L2,"财务",["outstanding balance"],["unpaid"],"","en-US","","Please settle the outstanding balance by Friday."),
      new ToeicVocabularyItem("V-116","installment","n.","分期付款额",ToeicVocabularyLevel.L2,"财务",["monthly installment"],["scheduled payment"],"","en-US","","The first monthly installment is due in June."),
      new ToeicVocabularyItem("V-117","forecast","n./v.","预测；预报",ToeicVocabularyLevel.L2,"经营",["sales forecast"],["projection"],"","en-US","","The latest sales forecast suggests steady growth."),
      new ToeicVocabularyItem("V-118","subsidy","n.","补贴；津贴",ToeicVocabularyLevel.L3,"财务",["government subsidy"],["financial support"],"","en-US","","The company applied for a training subsidy."),
      new ToeicVocabularyItem("V-119","productivity","n.","生产效率；生产率",ToeicVocabularyLevel.L2,"运营",["improve productivity"],["output efficiency"],"","en-US","","The new software is expected to improve productivity."),
      new ToeicVocabularyItem("V-120","promptly","adv.","及时地；迅速地",ToeicVocabularyLevel.L1,"服务",["respond promptly"],["quickly"],"","en-US","","Please respond promptly to customer requests.")
    ];
  }

  static idsForDay(day:number):string[] {
    // A small number of new words per day so the 21-day program remains manageable.
    if (day<2 || day>13) return [];
    let start=(day-2)*3;
    let ids:string[]=[];
    for (let index=start;index<Math.min(30,start+3);index++) {
      ids.push('V-'+String(91+index).padStart(3,'0'));
    }
    return ids;
  }
}
