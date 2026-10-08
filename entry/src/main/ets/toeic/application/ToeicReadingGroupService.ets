import { ToeicPart, ToeicQuestion, ToeicReadingGroup } from '../domain/ToeicModels';
import { ToeicExtraReadingContent } from '../content/ToeicExtraReadingContent';

/**
 * Build a view of existing published shared passages without changing any
 * questionId, answer version or the two 100-question mock sets.
 */
export class ToeicReadingGroupService {
  static groupAt(questions:ToeicQuestion[],index:number):ToeicReadingGroup {
    if (index<0 || index>=questions.length) return new ToeicReadingGroup('',[],[]);
    let current=questions[index];
    if (current.groupId.length>0) {
      for (let group of ToeicExtraReadingContent.groups()) {
        if (group.groupId!==current.groupId) continue;
        let presentIds:string[]=[];
        for (let id of group.questionIds) {
          for (let question of questions) {
            if (question.id===id) { presentIds.push(id); break; }
          }
        }
        return new ToeicReadingGroup(group.groupId,presentIds,group.passageBlocks);
      }
      return new ToeicReadingGroup('',[],[]);
    }
    if (current.passage.length===0 || current.part===ToeicPart.PART_5) {
      return new ToeicReadingGroup(current.id,[current.id],[]);
    }
    let first=index;
    while (first>0 && questions[first-1].part===current.part &&
      questions[first-1].passage===current.passage) first--;
    let last=index;
    while (last+1<questions.length && questions[last+1].part===current.part &&
      questions[last+1].passage===current.passage) last++;
    let ids:string[]=[];
    for (let i=first;i<=last;i++) ids.push(questions[i].id);
    return new ToeicReadingGroup(questions[first].id,ids,
      ToeicReadingGroupService.passageBlocks(current.passage));
  }

  static passageBlocks(passage:string):string[] {
    if (passage.trim().length===0) return [];
    // Existing Day 12/13 groups separate each article with DOCUMENT 1/2/3.
    // Only split at the start of a line; preserve headings and all evidence text.
    let boundaries:number[]=[0];
    for (let number=2;number<=3;number++) {
      let marker='DOCUMENT '+number;
      let index=passage.indexOf(marker);
      if (index>0 && passage.charAt(index-1)==='\n') boundaries.push(index);
    }
    boundaries.sort((a,b)=>a-b);
    let blocks:string[]=[];
    for (let i=0;i<boundaries.length;i++) {
      let end=i+1<boundaries.length?boundaries[i+1]:passage.length;
      blocks.push(passage.substring(boundaries[i],end).trim());
    }
    return blocks;
  }
}
