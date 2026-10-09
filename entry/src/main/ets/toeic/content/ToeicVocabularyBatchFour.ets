import { ToeicReviewStatus, ToeicVocabularyItem, ToeicVocabularyLevel } from '../domain/ToeicModels';

/** AI-reviewed V181–V210, released with content-bound editorial fingerprints. */
export class ToeicVocabularyBatchFour {
  static items():ToeicVocabularyItem[] {
    return [
      new ToeicVocabularyItem("V-181","consignment","n.","托运货物；寄售商品",ToeicVocabularyLevel.L3,"物流",["consignment of goods"],["shipment of goods"],"","en-US","","The carrier confirmed receipt of the consignment at the warehouse.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-182","fulfillment","n.","订单履行；履约",ToeicVocabularyLevel.L3,"物流",["order fulfillment"],["processing and delivery of orders"],"","en-US","","The retailer outsourced order fulfillment during the holiday season.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-183","backorder","n.","延期交付订单；缺货待交订单",ToeicVocabularyLevel.L3,"物流",["place an item on backorder"],["order awaiting stock"],"","en-US","","The printer cartridges are on backorder until next week.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-184","restock","v.","补货；重新进货",ToeicVocabularyLevel.L2,"物流",["restock shelves"],["replenish inventory"],"","en-US","","Staff will restock the shelves before the store opens.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-185","carrier","n.","承运商；运输公司",ToeicVocabularyLevel.L2,"物流",["freight carrier"],["transport company"],"","en-US","","The carrier will collect the packages on Tuesday.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-186","customs","n.","海关",ToeicVocabularyLevel.L2,"国际贸易",["clear customs"],["border authorities"],"","en-US","","The shipment was delayed while customs inspected the documents.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-187","tariff","n.","关税；收费表",ToeicVocabularyLevel.L3,"国际贸易",["import tariff"],["import duty"],"","en-US","","The new tariff increased the cost of imported components.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-188","clearance","n.","清关；许可",ToeicVocabularyLevel.L3,"国际贸易",["customs clearance"],["authorization to pass"],"","en-US","","Customs clearance usually takes two business days.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-189","pallet","n.","货物托盘",ToeicVocabularyLevel.L3,"仓储",["shipping pallet"],["flat platform for stacking and moving goods"],"","en-US","","Each pallet must be labeled before it leaves the warehouse.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-190","perishable","adj.","易腐坏的；易变质的",ToeicVocabularyLevel.L3,"物流",["perishable goods"],["likely to spoil quickly"],"","en-US","","Perishable products must be kept refrigerated during transport.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-191","wholesale","adj.","批发的",ToeicVocabularyLevel.L2,"零售",["wholesale price"],["sold in large quantities to businesses"],"","en-US","","The distributor offers a wholesale discount to business customers.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-192","retail","adj.","零售的",ToeicVocabularyLevel.L1,"零售",["retail price"],["sold directly to consumers"],"","en-US","","The retail price includes local sales tax.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-193","promotional","adj.","促销的；宣传性的",ToeicVocabularyLevel.L2,"营销",["promotional offer"],["intended to increase sales"],"","en-US","","The promotional price applies only to online orders.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-194","coupon","n.","优惠券；折扣券",ToeicVocabularyLevel.L1,"零售",["discount coupon"],["voucher"],"","en-US","","Customers may use one coupon per purchase.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-195","redeem","v.","兑换；使用优惠券",ToeicVocabularyLevel.L2,"零售",["redeem a voucher"],["exchange for a benefit"],"","en-US","","Members can redeem points for a gift card.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-196","exchange","n.","换货；交换",ToeicVocabularyLevel.L1,"客户服务",["request an exchange"],["replacement transaction"],"","en-US","","The customer requested an exchange for a different size.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-197","returnable","adj.","可退还的；可退货的",ToeicVocabularyLevel.L3,"客户服务",["returnable item"],["eligible for return"],"","en-US","","Opened software packages are not returnable under the store policy.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-198","defective","adj.","有缺陷的；有故障的",ToeicVocabularyLevel.L2,"质量",["defective product"],["faulty"],"","en-US","","The supplier replaced the defective parts without charge.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-199","markdown","n.","降价；减价金额",ToeicVocabularyLevel.L3,"零售",["price markdown"],["price reduction"],"","en-US","","The store announced a markdown on last season's jackets.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-200","merchandise","n.","商品；货品",ToeicVocabularyLevel.L2,"零售",["display merchandise"],["goods for sale"],"","en-US","","The new merchandise will be displayed near the entrance.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-201","malfunction","n.","故障；失灵",ToeicVocabularyLevel.L2,"技术支持",["equipment malfunction"],["failure to operate correctly"],"","en-US","","A malfunction interrupted the packing line for twenty minutes.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-202","troubleshoot","v.","排查故障并尝试解决",ToeicVocabularyLevel.L3,"技术支持",["troubleshoot a connection"],["identify a fault and seek a solution"],"","en-US","","The support engineer will troubleshoot the network connection.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-203","outage","n.","中断；停电；断网",ToeicVocabularyLevel.L2,"技术支持",["network outage"],["service interruption"],"","en-US","","The office could not access email during the network outage.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-204","downtime","n.","停机时间；服务不可用时间",ToeicVocabularyLevel.L3,"技术支持",["minimize downtime"],["period of unavailability"],"","en-US","","Preventive maintenance helps minimize equipment downtime.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-205","backup","n.","备份；后备方案",ToeicVocabularyLevel.L2,"技术支持",["data backup"],["reserve copy"],"","en-US","","The technician restored the files from the latest backup.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-206","deployment","n.","部署；投入使用",ToeicVocabularyLevel.L3,"技术支持",["software deployment"],["release into operation"],"","en-US","","The software deployment is scheduled for Sunday morning.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-207","cancellation","n.","取消；撤销",ToeicVocabularyLevel.L2,"客户服务",["cancellation fee"],["withdrawal of a booking"],"","en-US","","The hotel charges a cancellation fee when guests cancel after the deadline.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-208","expiration","n.","到期；期满",ToeicVocabularyLevel.L2,"合同",["expiration date"],["end of validity"],"","en-US","","The insurance policy must be renewed before its expiration.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-209","entitlement","n.","权利；应得福利",ToeicVocabularyLevel.L3,"人事",["benefit entitlement"],["right to a benefit"],"","en-US","","Employees can check their leave entitlement in the HR portal.",ToeicReviewStatus.PUBLISHED),
      new ToeicVocabularyItem("V-210","assistance","n.","协助；援助",ToeicVocabularyLevel.L1,"客户服务",["technical assistance"],["help"],"","en-US","","Please contact our help desk if you need technical assistance.",ToeicReviewStatus.PUBLISHED)
    ];
  }

  static idsForDay(day:number):string[] {
    if (day<2 || day>13) return [];
    let start=Math.floor((day-2)*30/12);
    let end=Math.floor((day-1)*30/12);
    let ids:string[]=[];
    for (let index=start;index<end;index++) ids.push('V-'+String(181+index));
    return ids;
  }
}
