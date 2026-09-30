export class ToeicQuestionTranslation {
  questionId:string;
  passage:string;
  stem:string;
  options:string[];

  constructor(questionId:string, passage:string, stem:string, options:string[]) {
    this.questionId=questionId;
    this.passage=passage;
    this.stem=stem;
    this.options=options;
  }
}
