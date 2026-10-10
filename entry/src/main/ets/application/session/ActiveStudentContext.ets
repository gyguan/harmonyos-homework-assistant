export class ActiveStudentContext {
  static readonly instance:ActiveStudentContext=new ActiveStudentContext();
  private studentId:string='';

  private constructor() {}

  set(studentId:string):void { this.studentId=studentId.trim(); }
  clear():void { this.studentId=''; }
  get():string { return this.studentId; }
}
