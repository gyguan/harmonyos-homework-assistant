import {
  ToeicVocabularyItem, ToeicVocabularyQuizMode, ToeicVocabularyQuizQuestion
} from '../domain/ToeicModels';

/** Deterministic 4-choice retrieval practice based only on the approved TOEIC word assets. */
export class ToeicVocabularyQuizService {
  static generate(selected:ToeicVocabularyItem[],catalog:ToeicVocabularyItem[],
    mode:ToeicVocabularyQuizMode):ToeicVocabularyQuizQuestion[] {
    let result:ToeicVocabularyQuizQuestion[]=[];
    for (let i=0;i<selected.length;i++) {
      let item=selected[i];
      let answer=ToeicVocabularyQuizService.answerFor(item,mode);
      if (answer.length===0) continue;
      let distractors:string[]=[];
      for (let offset=1;offset<=catalog.length && distractors.length<3;offset++) {
        let candidate=catalog[(i*11+offset*7)%catalog.length];
        if (candidate.id===item.id || candidate.scenario===item.scenario) continue;
        let option=ToeicVocabularyQuizService.answerFor(candidate,mode);
        if (option.length>0 && option!==answer && distractors.indexOf(option)<0) distractors.push(option);
      }
      if (distractors.length!==3) continue;
      let correctIndex=(i*3+1)%4;
      let options:string[]=[];
      let otherIndex=0;
      for (let j=0;j<4;j++) {
        if (j===correctIndex) options.push(answer);
        else { options.push(distractors[otherIndex]); otherIndex++; }
      }
      let stem=ToeicVocabularyQuizService.promptFor(item,mode);
      result.push(new ToeicVocabularyQuizQuestion(item.id,mode,stem,options,correctIndex,
        '正确表达：'+answer+'；原词：'+item.word+'，'+item.meaning));
    }
    return result;
  }

  private static answerFor(item:ToeicVocabularyItem,mode:ToeicVocabularyQuizMode):string {
    if (mode===ToeicVocabularyQuizMode.MEANING) return item.meaning;
    if (mode===ToeicVocabularyQuizMode.COLLOCATION) {
      return item.collocations.length>0?item.collocations[0]:'';
    }
    return item.paraphrases.length>0?item.paraphrases[0]:'';
  }

  private static promptFor(item:ToeicVocabularyItem,mode:ToeicVocabularyQuizMode):string {
    if (mode===ToeicVocabularyQuizMode.MEANING) return '选择 '+item.word+' 的正确中文释义';
    if (mode===ToeicVocabularyQuizMode.COLLOCATION) return '下列哪一项是 '+item.word+' 的商务常用搭配？';
    return item.word+' 的近义表达是哪一项？';
  }
}
