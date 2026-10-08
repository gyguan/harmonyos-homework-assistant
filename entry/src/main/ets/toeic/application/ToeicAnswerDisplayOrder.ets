/**
 * Deterministic visual option order for TOEIC reading items.
 *
 * Answer keys and stored selectedIndex always refer to the canonical authored
 * option order. Only the four displayed options (and corresponding translations)
 * are permuted. That keeps legacy attempts, drafts, statistics and editorial
 * fingerprints stable while removing the extreme authored answer-position bias.
 *
 * The item ID is the only seed. Never include current time or attempt count:
 * navigation, draft restoration and reattempts must show the same option texts
 * under the same displayed letters.
 */
export class ToeicAnswerDisplayOrder {
  static order(questionId:string):number[] {
    let seed:number=0;
    for (let i=0;i<questionId.length;i++) {
      seed=(seed*131+questionId.charCodeAt(i))%65521;
    }
    let order:number[]=[0,1,2,3];
    for (let i=3;i>0;i--) {
      seed=(seed*25173+13849)%65521;
      let j=seed%(i+1);
      let t=order[i];
      order[i]=order[j];
      order[j]=t;
    }
    return order;
  }

  static displayIndex(order:number[],canonicalIndex:number):number {
    return order.indexOf(canonicalIndex);
  }
}
