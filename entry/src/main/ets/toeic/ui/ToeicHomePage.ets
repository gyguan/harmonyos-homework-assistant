import { LengthMetrics } from '@kit.ArkUI';
import { LayoutPolicy } from '../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../common/theme/AppTheme';
import { DeepPageHeader } from '../../components/navigation/DeepPageHeader';
import { ToeicPart, ToeicPerformance, ToeicMockReport, ToeicSessionReport, ToeicQuestion, ToeicQuestionAttempt, ToeicQuestionTime, ToeicScoreValue, ToeicSentenceDrill, ToeicSessionDraft, ToeicSkill, ToeicVocabularyItem, ToeicVocabularyQuizMode, ToeicVocabularyQuizQuestion } from '../domain/ToeicModels';
import { ToeicCoachViewModel } from './ToeicCoachViewModel';
import { ToeicPronunciationStatus } from '../application/ToeicPronunciationService';
import { ToeicReadingGroupService } from '../application/ToeicReadingGroupService';
import { ToeicVocabularyQuizService } from '../application/ToeicVocabularyQuizService';

enum ToeicPageMode { HOME='HOME', DIAGNOSTIC='DIAGNOSTIC', TRAINING='TRAINING', VOCABULARY='VOCABULARY', VOCABULARY_QUIZ='VOCABULARY_QUIZ', SENTENCE='SENTENCE', MOCK_RESULT='MOCK_RESULT' }

@Component
export struct ToeicHomePage {
  @State private availableWidthVp:number=390;
  @State private mode:ToeicPageMode=ToeicPageMode.HOME;
  @State private questions:ToeicQuestion[]=[];
  @State private currentIndex:number=0;
  @State private selectedIndex:number=-1;
  @State private answerLocked:boolean=false;
  @State private answerCorrect:boolean=false;
  @State private questionStartedAtMs:number=0;
  @State private refreshRevision:number=0;
  @State private pronunciationMessage:string='';
  @State private selectedStudyDay:number=0;
  @State private selectedDayTitle:string='';
  @State private selectedDayFocus:string='';
  @State private selectedDayMinutes:number=0;
  @State private selectedDayVocabularyCount:number=0;
  @State private selectedDaySentenceCount:number=0;
  @State private selectedVocabDone:boolean=false;
  @State private selectedSentenceDone:boolean=false;
  @State private selectedTrainingDone:boolean=false;
  @State private showFullPlan:boolean=false;
  @State private recentReports:ToeicSessionReport[]=[];
  @State private progressCurrentDay:number=1;
  @State private progressDiagnosticCompleted:boolean=false;
  @State private progressWeakSkill:string='';
  @State private progressReviewCount:number=0;
  @State private progressSlowCount:number=0;
  @State private progressAnswered:number=0;
  @State private progressCorrect:number=0;
  @State private progressAccuracy:string='--';
  @State private activeSessionDay:number=0;
  @State private activeSessionAdvancesProgress:boolean=false;
  @State private mockResultDay:number=0;
  @State private mockResultCorrect:number=0;
  @State private mockResultTotal:number=0;
  @State private mockResultAnswered:number=0;
  @State private mockResultUnanswered:number=0;
  @State private mockPart5Correct:number=0;
  @State private mockPart5Total:number=0;
  @State private mockPart6Correct:number=0;
  @State private mockPart6Total:number=0;
  @State private mockPart7Correct:number=0;
  @State private mockPart7Total:number=0;
  @State private mockElapsedSeconds:number=0;
  @State private mockCountdownSeconds:number=4500;
  @State private draftLabel:string='';
  @State private navigatorVisible:boolean=false;
  @State private revealedWordIds:string[]=[];
  @State private revealedSentenceIds:string[]=[];
  @State private lastReviewedWordId:string='';
  @State private vocabularyFeedback:string='';
  @State private quizStem:string='';
  @State private quizOptionA:string='';
  @State private quizOptionB:string='';
  @State private quizOptionC:string='';
  @State private quizOptionD:string='';
  @State private quizAnswerIndex:number=-1;
  @State private quizSelectedIndex:number=-1;
  @State private quizPosition:number=0;
  @State private quizCorrectCount:number=0;
  @State private quizModeLabel:string='';
  @State private quizExplanation:string='';
  private quizQuestions:ToeicVocabularyQuizQuestion[]=[];
  @State private markedQuestionIds:string[]=[];
  @State private mockReports:ToeicMockReport[]=[];
  private sessionStartedAtMs:number=0;
  private questionTimes:ToeicQuestionTime[]=[];
  private mockClockId:number=-1;
  private finishingSession:boolean=false;
  @State private currentQuestionId:string='';
  @State private currentPassage:string='';
  @State private currentPassageBlocks:string[]=[];
  @State private currentGroupPosition:number=0;
  @State private currentGroupCount:number=0;
  @State private currentStem:string='';
  @State private currentOptionCount:number=0;
  @State private currentOptionA:string='';
  @State private currentOptionB:string='';
  @State private currentOptionC:string='';
  @State private currentOptionD:string='';
  @State private showQuestionTranslation:boolean=false;
  @State private currentTranslationPassage:string='';
  @State private currentTranslationStem:string='';
  @State private currentTranslationOptionA:string='';
  @State private currentTranslationOptionB:string='';
  @State private currentTranslationOptionC:string='';
  @State private currentTranslationOptionD:string='';
  @State private currentCorrectIndex:number=-1;
  @State private currentAttemptCount:number=0;
  @State private currentWrongCount:number=0;
  @State private currentExplanation:string='';
  @State private currentEvidence:string='';
  @State private currentParaphrase:string='';
  @State private currentRecommendedSeconds:number=0;
  @State private currentPart:ToeicPart=ToeicPart.PART_5;
  @State private currentSkill:ToeicSkill=ToeicSkill.WORD_FORM;
  @State private currentScoreValue:ToeicScoreValue=ToeicScoreValue.MUST_GET;
  private readonly viewModel:ToeicCoachViewModel=new ToeicCoachViewModel();
  private attempts:ToeicQuestionAttempt[]=[];

  aboutToAppear():void {
    this.loadProgressSnapshot();
    if (this.selectedStudyDay<=0) this.selectedStudyDay=this.progressCurrentDay;
    this.loadStudyDay(this.selectedStudyDay);
    this.refreshRevision++;
    if (this.isMockSession() && this.mode===ToeicPageMode.TRAINING) this.startMockClock();
  }

  aboutToDisappear():void {
    this.stopMockClock();
    if (!this.finishingSession && this.questions.length>0 &&
      (this.mode===ToeicPageMode.TRAINING || this.mode===ToeicPageMode.DIAGNOSTIC)) {
      this.noteCurrentQuestionTime();
      this.persistDraft();
    }
  }

  private stopMockClock():void {
    if (this.mockClockId>=0) {
      clearInterval(this.mockClockId);
      this.mockClockId=-1;
    }
  }

  private mockExpired():boolean {
    return this.isMockSession() && Date.now()>=this.sessionStartedAtMs+75*60*1000;
  }

  private updateMockClock():void {
    if (!this.isMockSession() || this.mode!==ToeicPageMode.TRAINING) return;
    this.mockCountdownSeconds=Math.max(0,
      Math.ceil((this.sessionStartedAtMs+75*60*1000-Date.now())/1000));
    if (this.mockCountdownSeconds===0) {
      this.stopMockClock();
      void this.finishSession();
    }
  }

  private startMockClock():void {
    this.stopMockClock();
    this.updateMockClock();
    if (this.mode===ToeicPageMode.TRAINING && this.isMockSession() && !this.finishingSession) {
      this.mockClockId=setInterval(()=>this.updateMockClock(),1000);
    }
  }

  private clockLabel():string {
    let minutes=Math.floor(this.mockCountdownSeconds/60);
    let seconds=this.mockCountdownSeconds%60;
    return String(minutes).padStart(2,'0')+':'+String(seconds).padStart(2,'0');
  }

  private currentQuestionForAttempt():ToeicQuestion|null {
    if (this.currentQuestionId.length===0) return null;
    for (let question of this.questions) {
      if (question.id===this.currentQuestionId) return question;
    }
    return null;
  }

  private sessionAttempt(questionId:string):ToeicQuestionAttempt|null {
    for (let attempt of this.attempts) {
      if (attempt.questionId===questionId) return attempt;
    }
    return null;
  }

  private loadQuestion(index:number):boolean {
    if (index<0 || index>=this.questions.length) return false;
    let question=this.questions[index];
    let attempt=this.sessionAttempt(question.id);
    this.currentQuestionId=question.id;
    this.currentPassage=question.passage;
    let readingGroup=ToeicReadingGroupService.groupAt(this.questions,index);
    this.currentPassageBlocks=readingGroup.passageBlocks;
    if (question.groupId.length>0 && readingGroup.passageBlocks.length>0) {
      this.currentPassage=readingGroup.passageBlocks.join('\n\n');
    }
    this.currentGroupCount=readingGroup.questionIds.length;
    this.currentGroupPosition=readingGroup.questionIds.indexOf(question.id)+1;
    this.currentStem=question.stem;
    this.currentOptionCount=question.options.length;
    this.currentOptionA=question.options.length>0?question.options[0]:'';
    this.currentOptionB=question.options.length>1?question.options[1]:'';
    this.currentOptionC=question.options.length>2?question.options[2]:'';
    this.currentOptionD=question.options.length>3?question.options[3]:'';
    let translation=this.viewModel.questionTranslation(question.id);
    this.showQuestionTranslation=false;
    this.currentTranslationPassage=translation===null?'':translation.passage;
    this.currentTranslationStem=translation===null?'':translation.stem;
    this.currentTranslationOptionA=translation===null || translation.options.length<1?'':translation.options[0];
    this.currentTranslationOptionB=translation===null || translation.options.length<2?'':translation.options[1];
    this.currentTranslationOptionC=translation===null || translation.options.length<3?'':translation.options[2];
    this.currentTranslationOptionD=translation===null || translation.options.length<4?'':translation.options[3];
    this.currentCorrectIndex=question.correctIndex;
    this.currentAttemptCount=this.viewModel.attemptCount(question.id)+(attempt===null?0:1);
    this.currentWrongCount=this.viewModel.wrongCount(question.id)+(attempt!==null && !attempt.correct?1:0);
    this.currentExplanation=question.explanation;
    this.currentEvidence=question.evidence;
    this.currentParaphrase=question.paraphrase;
    this.currentRecommendedSeconds=question.recommendedSeconds;
    this.currentPart=question.part;
    this.currentSkill=question.skill;
    this.currentScoreValue=question.scoreValue;
    this.selectedIndex=attempt===null?-1:attempt.selectedIndex;
    this.answerCorrect=attempt===null?false:attempt.correct;
    this.answerLocked=attempt!==null;
    this.questionStartedAtMs=Date.now();
    return true;
  }

  private clearQuestionSnapshot():void {
    this.currentQuestionId='';
    this.currentPassage='';
    this.currentPassageBlocks=[];
    this.currentGroupPosition=0;
    this.currentGroupCount=0;
    this.currentStem='';
    this.currentOptionCount=0;
    this.currentOptionA='';
    this.currentOptionB='';
    this.currentOptionC='';
    this.currentOptionD='';
    this.showQuestionTranslation=false;
    this.currentTranslationPassage='';
    this.currentTranslationStem='';
    this.currentTranslationOptionA='';
    this.currentTranslationOptionB='';
    this.currentTranslationOptionC='';
    this.currentTranslationOptionD='';
    this.currentCorrectIndex=-1;
    this.currentAttemptCount=0;
    this.currentWrongCount=0;
    this.currentExplanation='';
    this.currentEvidence='';
    this.currentParaphrase='';
    this.currentRecommendedSeconds=0;
    this.currentPart=ToeicPart.PART_5;
    this.currentSkill=ToeicSkill.WORD_FORM;
    this.currentScoreValue=ToeicScoreValue.MUST_GET;
  }

  private loadProgressSnapshot():void {
    let snapshot=this.viewModel.snapshot();
    this.progressCurrentDay=snapshot.currentDay;
    this.progressDiagnosticCompleted=snapshot.diagnosticCompleted;
    this.progressWeakSkill=snapshot.weakSkill;
    this.progressReviewCount=snapshot.reviewQuestionIds.length;
    this.progressSlowCount=snapshot.slowQuestionIds.length;
    this.progressAnswered=snapshot.totalAnswered;
    this.progressCorrect=snapshot.totalCorrect;
    this.progressAccuracy=this.viewModel.accuracyValue(snapshot);
    this.mockReports=snapshot.mockReports.slice();
    this.recentReports=snapshot.sessionReports.slice(-3).reverse();
    let draft=snapshot.activeDraft;
    this.draftLabel=draft===null?'':'Day '+draft.day+' · '+
      (draft.day===14 || draft.day===19?'完整模考':'专项训练')+
      '（已答 '+draft.attempts.length+'/'+draft.questionIds.length+'）';
  }

  private effectiveStudyDay():number {
    if (this.selectedStudyDay>0) return this.selectedStudyDay;
    return this.progressCurrentDay;
  }

  private loadStudyDay(day:number):void {
    let plan=this.viewModel.planForDay(day);
    this.selectedDayTitle=plan.title;
    this.selectedDayFocus=plan.focus;
    this.selectedDayMinutes=plan.estimatedMinutes;
    this.selectedDayVocabularyCount=this.viewModel.vocabularyForDay(day).length;
    this.selectedDaySentenceCount=plan.sentenceDrillIds.length;
    let progress=this.viewModel.dayTaskProgress(day);
    this.selectedVocabDone=progress.vocabularyCompleted;
    this.selectedSentenceDone=progress.sentenceCompleted;
    this.selectedTrainingDone=progress.trainingCompleted;
  }

  private completedTasksCount():number {
    let count=0;
    if (this.selectedDayVocabularyCount===0 || this.selectedVocabDone) count++;
    if (this.selectedDaySentenceCount===0 || this.selectedSentenceDone) count++;
    if (this.selectedTrainingDone) count++;
    return count;
  }

  private async finishDayTask(task:string):Promise<void> {
    await this.viewModel.completeDayTask(this.selectedStudyDay,task);
    this.loadProgressSnapshot();
    if (this.selectedStudyDay!==this.progressCurrentDay &&
      this.selectedStudyDay+1===this.progressCurrentDay) {
      this.selectedStudyDay=this.progressCurrentDay;
    }
    this.loadStudyDay(this.selectedStudyDay);
    this.mode=ToeicPageMode.HOME;
    this.refreshRevision++;
  }

  private lastSessionHeadline(report:ToeicSessionReport):string {
    let accuracy=report.answered>0?Math.round(report.correct*100/report.answered):0;
    return 'Day '+report.day+' · '+report.correct+'/'+report.answered+
      '（'+accuracy+'%）· 慢题 '+report.slow;
  }

  private selectStudyDay(day:number):void {
    if (day<1 || day>21) return;
    this.selectedStudyDay=day;
    this.loadStudyDay(day);
    this.refreshRevision++;
    this.pronunciationMessage='';
  }

  private dayContextLabel(day:number):string {
    if (day===this.progressCurrentDay) return '当前进度';
    if (day<this.progressCurrentDay) return '复习';
    return '预习';
  }

  private selectedDayGuidance():string {
    if (this.selectedStudyDay===14) {
      return 'Day 14 为第一次完整 Reading 模考：75 分钟、100 题固定题序，作答过程中不显示答案，结束后统一查看结果。';
    }
    if (this.selectedStudyDay===18) {
      return 'Day 18 根据当前错题、慢题和薄弱能力动态组题，优先修复最影响 350+ 目标的失分点。';
    }
    if (this.selectedStudyDay===19) {
      return 'Day 19 为第二次完整 Reading 模考：75 分钟、100 题独立题集，用于验证第一轮补弱后的提升。';
    }
    if (this.selectedStudyDay===20) {
      return 'Day 20 优先复盘累计错 2 次及以上题目，再处理当前错题、慢题和薄弱能力。';
    }
    if (this.selectedStudyDay===21) {
      return 'Day 21 只做轻量最终验证：P5 15题 + P6 8题 + P7 12题，不再堆新难题。';
    }
    return '进入 Day '+this.selectedStudyDay+' 后只训练这一天的计划题；本日错题和慢题会优先出现。';
  }

  private trainingButtonLabel():string {
    if (this.selectedStudyDay===1) {
      return this.progressDiagnosticCompleted?'重新进行 Day 1 快速诊断':'进入 Day 1 快速诊断';
    }
    if (this.selectedStudyDay===14) return '开始 Day 14 第一次完整模考';
    if (this.selectedStudyDay===18) return '开始 Day 18 动态补弱';
    if (this.selectedStudyDay===19) return '开始 Day 19 第二次完整模考';
    if (this.selectedStudyDay===20) return '开始 Day 20 错题收口';
    if (this.selectedStudyDay===21) return '开始 Day 21 最终验证';
    return '进入 Day '+this.selectedStudyDay+' 训练';
  }

  private isMockSession():boolean {
    return this.activeSessionDay===14 || this.activeSessionDay===19;
  }

  private captureMockResult():void {
    this.mockResultDay=this.activeSessionDay;
    this.mockResultCorrect=0;
    this.mockResultTotal=this.questions.length;
    this.mockResultAnswered=this.attempts.length;
    this.mockResultUnanswered=this.questions.length-this.attempts.length;
    this.mockPart5Correct=0;
    this.mockPart5Total=0;
    this.mockPart6Correct=0;
    this.mockPart6Total=0;
    this.mockPart7Correct=0;
    this.mockPart7Total=0;
    this.mockElapsedSeconds=Math.min(75*60,Math.max(1,Math.round((Date.now()-this.sessionStartedAtMs)/1000)));
    for (let attempt of this.attempts) {
      if (attempt.correct) this.mockResultCorrect++;
      if (attempt.part===ToeicPart.PART_5) {
        this.mockPart5Total++;
        if (attempt.correct) this.mockPart5Correct++;
      } else if (attempt.part===ToeicPart.PART_6) {
        this.mockPart6Total++;
        if (attempt.correct) this.mockPart6Correct++;
      } else if (attempt.part===ToeicPart.PART_7) {
        this.mockPart7Total++;
        if (attempt.correct) this.mockPart7Correct++;
      }
    }
  }

  private mockComparisonLabel():string {
    let first:ToeicMockReport|null=null;
    let second:ToeicMockReport|null=null;
    for (let report of this.mockReports) {
      if (report.day===14) first=report;
      if (report.day===19) second=report;
    }
    if (first===null || second===null) return '';
    let difference=second.correctCount-first.correctCount;
    return '二模相较一模：'+(difference>0?'+':'')+difference+' 题；'+
      'Part 5 '+(second.part5Correct-first.part5Correct)+
      '，Part 6 '+(second.part6Correct-first.part6Correct)+
      '，Part 7 '+(second.part7Correct-first.part7Correct);
  }

  private leaveMockResult():void {
    this.mode=ToeicPageMode.HOME;
    this.activeSessionDay=0;
    this.activeSessionAdvancesProgress=false;
  }

  private startDiagnostic():void {
    this.activeSessionDay=1;
    this.activeSessionAdvancesProgress=!this.progressDiagnosticCompleted;
    this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.diagnosticQuestions());
  }

  private startSupplementaryReading():void {
    let questions=this.viewModel.supplementaryReadingQuestions();
    if (questions.length===0) return;
    // Extra reading is optional and must not advance the current study day.
    this.activeSessionDay=17;
    this.activeSessionAdvancesProgress=false;
    this.startSession(ToeicPageMode.TRAINING,questions);
  }

  private startStandardDiagnostic():void {
    // Extra 12 questions never substitute for the Day 1 quick diagnostic milestone.
    this.activeSessionDay=1;
    this.activeSessionAdvancesProgress=false;
    this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.standardDiagnosticQuestions());
  }

  private startTraining():void {
    let day=this.effectiveStudyDay();
    if (day===1) {
      this.activeSessionDay=1;
      this.activeSessionAdvancesProgress=!this.progressDiagnosticCompleted;
      this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.diagnosticQuestions());
      return;
    }
    this.activeSessionDay=day;
    this.activeSessionAdvancesProgress=day===this.progressCurrentDay;
    this.startSession(ToeicPageMode.TRAINING,this.viewModel.dailyQuestionsForDay(day));
  }

  private openVocabulary():void {
    this.pronunciationMessage='';
    this.revealedWordIds=[];
    this.lastReviewedWordId='';
    this.vocabularyFeedback='';
    this.mode=ToeicPageMode.VOCABULARY;
  }
  private openSentenceDrills():void {
    this.revealedSentenceIds=[];
    this.mode=ToeicPageMode.SENTENCE;
  }

  private toggleWordReveal(id:string):void {
    let next=this.revealedWordIds.slice();
    let index=next.indexOf(id);
    if (index>=0) next.splice(index,1);
    else next.push(id);
    this.revealedWordIds=next;
  }

  private startVocabularyQuiz(mode:ToeicVocabularyQuizMode):void {
    let selected=this.viewModel.vocabularyForDay(this.effectiveStudyDay());
    this.quizQuestions=ToeicVocabularyQuizService.generate(
      selected,this.viewModel.allVocabulary(),mode);
    if (this.quizQuestions.length===0) return;
    this.quizCorrectCount=0;
    this.quizModeLabel=mode===ToeicVocabularyQuizMode.MEANING?'词义':
      (mode===ToeicVocabularyQuizMode.COLLOCATION?'商务搭配':'同义替换');
    this.loadVocabularyQuiz(0);
    this.mode=ToeicPageMode.VOCABULARY_QUIZ;
  }

  private loadVocabularyQuiz(index:number):void {
    if (index<0 || index>=this.quizQuestions.length) return;
    let quiz=this.quizQuestions[index];
    this.quizPosition=index;
    this.quizStem=quiz.stem;
    this.quizOptionA=quiz.options[0];
    this.quizOptionB=quiz.options[1];
    this.quizOptionC=quiz.options[2];
    this.quizOptionD=quiz.options[3];
    this.quizAnswerIndex=quiz.correctIndex;
    this.quizSelectedIndex=-1;
    this.quizExplanation=quiz.explanation;
  }

  private answerVocabularyQuiz(index:number):void {
    if (this.quizSelectedIndex>=0 || this.quizPosition>=this.quizQuestions.length) return;
    this.quizSelectedIndex=index;
    if (index===this.quizAnswerIndex) this.quizCorrectCount++;
    let question=this.quizQuestions[this.quizPosition];
    void this.viewModel.recordVocabularyRecall(question.vocabularyId,index===this.quizAnswerIndex);
  }

  private nextVocabularyQuiz():void {
    if (this.quizSelectedIndex<0) return;
    if (this.quizPosition+1>=this.quizQuestions.length) {
      void this.finishDayTask('vocabulary');
      return;
    }
    this.loadVocabularyQuiz(this.quizPosition+1);
  }

  private async recordWordRecall(item:ToeicVocabularyItem,remembered:boolean):Promise<void> {
    await this.viewModel.recordVocabularyRecall(item.id,remembered);
    this.lastReviewedWordId=item.id;
    this.vocabularyFeedback=remembered?'已记住，系统将按掌握度安排复习。':'还没记住，已安排短期复习。';
    this.loadStudyDay(this.selectedStudyDay);
    this.refreshRevision++;
  }

  private toggleSentenceReveal(id:string):void {
    let next=this.revealedSentenceIds.slice();
    let index=next.indexOf(id);
    if (index>=0) next.splice(index,1);
    else next.push(id);
    this.revealedSentenceIds=next;
  }

  private async pronounce(item:ToeicVocabularyItem):Promise<void> {
    this.pronunciationMessage='';
    let status=await this.viewModel.pronounce(item);
    if (status===ToeicPronunciationStatus.DOWNLOAD_STARTED) {
      this.pronunciationMessage='首次使用需要英语发音资源，请按系统提示完成下载后再次点击发音。';
    } else if (status===ToeicPronunciationStatus.UNSUPPORTED) {
      this.pronunciationMessage='当前设备暂不支持系统英语发音，音标和词汇内容仍可正常学习。';
    } else if (status===ToeicPronunciationStatus.FAILED) {
      this.pronunciationMessage='发音服务暂不可用，请稍后重试。';
    }
  }

  private spentForQuestion(questionId:string):number {
    for (let entry of this.questionTimes) if (entry.questionId===questionId) return entry.spentSeconds;
    return 0;
  }

  private noteCurrentQuestionTime():void {
    if (this.currentQuestionId.length===0 || this.questionStartedAtMs<=0) return;
    let elapsed=Math.max(0,Math.round((Date.now()-this.questionStartedAtMs)/1000));
    let item:ToeicQuestionTime|null=null;
    for (let entry of this.questionTimes) if (entry.questionId===this.currentQuestionId) { item=entry; break; }
    if (item===null) {
      item=new ToeicQuestionTime(this.currentQuestionId,elapsed);
      this.questionTimes.push(item);
    } else {
      item.spentSeconds+=elapsed;
    }
    this.questionStartedAtMs=Date.now();
    let attempt=this.sessionAttempt(this.currentQuestionId);
    if (attempt!==null && this.isMockSession()) attempt.elapsedSeconds=Math.max(1,item.spentSeconds);
  }

  private persistDraft():void {
    if (this.questions.length===0 || this.sessionStartedAtMs<=0) return;
    let questionIds:string[]=[];
    for (let question of this.questions) questionIds.push(question.id);
    let draft=new ToeicSessionDraft(this.activeSessionDay,this.mode,
      questionIds,this.currentIndex,this.attempts.slice(),this.questionTimes.slice(),
      this.sessionStartedAtMs,this.activeSessionAdvancesProgress,this.markedQuestionIds.slice());
    void this.viewModel.saveDraft(draft);
    this.draftLabel='Day '+draft.day+' · '+
      (this.isMockSession()?'完整模考':'专项训练')+
      '（已答 '+draft.attempts.length+'/'+draft.questionIds.length+'）';
  }

  private resumeDraft():void {
    let draft=this.viewModel.activeDraft();
    if (draft===null) return;
    let restored=this.viewModel.questionsForDraft(draft);
    if (restored.length===0 || restored.length!==draft.questionIds.length) {
      void this.viewModel.discardDraft();
      this.draftLabel='';
      return;
    }
    this.activeSessionDay=draft.day;
    this.activeSessionAdvancesProgress=draft.advancesProgress;
    this.mode=draft.mode===ToeicPageMode.DIAGNOSTIC?ToeicPageMode.DIAGNOSTIC:ToeicPageMode.TRAINING;
    this.questions=restored;
    this.attempts=draft.attempts.slice();
    this.questionTimes=draft.questionTimes.slice();
    this.markedQuestionIds=draft.markedQuestionIds.slice();
    this.navigatorVisible=false;
    this.sessionStartedAtMs=draft.startedAtMs;
    this.currentIndex=Math.min(Math.max(0,draft.currentIndex),restored.length-1);
    this.finishingSession=false;
    this.loadQuestion(this.currentIndex);
    if (this.isMockSession()) this.startMockClock();
  }

  private discardSavedDraft():void {
    void this.viewModel.discardDraft();
    this.draftLabel='';
  }

  private startSession(mode:ToeicPageMode,questions:ToeicQuestion[]):void {
    if (questions.length===0) return;
    this.stopMockClock();
    this.questions=questions;
    this.currentIndex=0;
    this.attempts=[];
    this.questionTimes=[];
    this.markedQuestionIds=[];
    this.navigatorVisible=false;
    this.sessionStartedAtMs=Date.now();
    this.finishingSession=false;
    this.loadQuestion(0);
    this.mode=mode;
    this.persistDraft();
    if (this.isMockSession()) this.startMockClock();
  }

  private cancelSession():void {
    if (this.finishingSession) return;
    this.noteCurrentQuestionTime();
    this.persistDraft(); // Return to home without losing unfinished answers.
    this.stopMockClock();
    this.mode=ToeicPageMode.HOME;
    this.questions=[];
    this.attempts=[];
    this.questionTimes=[];
    this.markedQuestionIds=[];
    this.navigatorVisible=false;
    this.answerLocked=false;
    this.selectedIndex=-1;
    this.clearQuestionSnapshot();
    this.activeSessionDay=0;
    this.sessionStartedAtMs=0;
  }

  private chooseAnswer(index:number):void {
    if (this.finishingSession || (this.answerLocked && !this.isMockSession())) return;
    if (this.mockExpired()) { void this.finishSession(); return; }
    let question=this.currentQuestionForAttempt();
    if (question===null || question.id!==this.currentQuestionId) return;
    let existing=this.sessionAttempt(this.currentQuestionId);
    if (existing!==null && !this.isMockSession()) return;
    let elapsed=Math.max(1,Math.round((Date.now()-this.questionStartedAtMs)/1000)+
      this.spentForQuestion(this.currentQuestionId));
    let attempt=this.viewModel.createAttempt(question,index,elapsed);
    if (existing!==null) {
      for (let i=0;i<this.attempts.length;i++) {
        if (this.attempts[i].questionId===question.id) { this.attempts[i]=attempt; break; }
      }
    } else {
      this.attempts.push(attempt);
      this.currentAttemptCount++;
      if (!this.isMockSession() && !attempt.correct) this.currentWrongCount++;
    }
    this.selectedIndex=index;
    this.answerCorrect=attempt.correct;
    this.answerLocked=true;
    this.persistDraft();
  }

  private previousQuestion():void {
    if (this.currentIndex<=0 || this.finishingSession) return;
    if (this.mockExpired()) { void this.finishSession(); return; }
    this.noteCurrentQuestionTime();
    this.currentIndex--;
    this.loadQuestion(this.currentIndex);
    this.persistDraft();
  }

  private nextQuestion():void {
    if (this.finishingSession || (!this.answerLocked && !this.isMockSession())) return;
    if (this.mockExpired()) { void this.finishSession(); return; }
    let nextIndex=this.currentIndex+1;
    if (nextIndex>=this.questions.length) {
      if (this.isMockSession()) this.confirmMockSubmission();
      else void this.finishSession();
      return;
    }
    this.noteCurrentQuestionTime();
    this.currentIndex=nextIndex;
    this.loadQuestion(nextIndex);
    this.persistDraft();
  }

  private isQuestionMarked(questionId:string):boolean {
    return this.markedQuestionIds.indexOf(questionId)>=0;
  }

  private toggleQuestionMark():void {
    if (!this.isMockSession() || this.currentQuestionId.length===0) return;
    let next=this.markedQuestionIds.slice();
    let index=next.indexOf(this.currentQuestionId);
    if (index>=0) next.splice(index,1);
    else next.push(this.currentQuestionId);
    this.markedQuestionIds=next;
    this.persistDraft();
  }

  private jumpToQuestion(index:number):void {
    if (!this.isMockSession() || index<0 || index>=this.questions.length ||
      this.finishingSession) return;
    if (this.mockExpired()) { void this.finishSession(); return; }
    this.noteCurrentQuestionTime();
    this.currentIndex=index;
    this.loadQuestion(index);
    this.persistDraft();
  }

  private confirmMockSubmission():void {
    let remaining=this.questions.length-this.attempts.length;
    this.getUIContext().showAlertDialog({
      title:'提交完整模考',
      message:remaining>0?'还有 '+remaining+' 题未作答，确定现在提交吗？':'确定提交本次完整模考吗？',
      primaryButton:{value:'继续作答',action:()=>{}},
      secondaryButton:{value:'提交模考',action:()=>{ void this.finishSession(); }}
    });
  }

  private async finishSession():Promise<void> {
    if (this.finishingSession || this.questions.length===0 || this.sessionStartedAtMs===0) return;
    this.finishingSession=true;
    this.stopMockClock();
    this.noteCurrentQuestionTime();
    let advanceProgress=this.activeSessionAdvancesProgress;
    let mockSession=this.isMockSession();
    let report:ToeicMockReport|null=null;
    if (mockSession) {
      this.captureMockResult();
      report=new ToeicMockReport(this.mockResultDay,Date.now(),this.mockResultCorrect,
        this.mockResultAnswered,this.mockResultTotal,this.mockElapsedSeconds,
        this.mockPart5Correct,this.mockPart6Correct,this.mockPart7Correct);
    }
    await this.viewModel.completeSession(this.attempts,this.mode===ToeicPageMode.DIAGNOSTIC,
      advanceProgress,report,this.activeSessionDay);
    this.loadProgressSnapshot();
    if (advanceProgress) {
      this.selectedStudyDay=this.progressCurrentDay;
      this.loadStudyDay(this.selectedStudyDay);
    }
    this.refreshRevision++;
    this.mode=mockSession?ToeicPageMode.MOCK_RESULT:ToeicPageMode.HOME;
    this.questions=[]; this.attempts=[]; this.questionTimes=[]; this.markedQuestionIds=[];
    this.answerLocked=false; this.selectedIndex=-1;
    this.clearQuestionSnapshot();
    this.sessionStartedAtMs=0;
    this.activeSessionDay=0; this.activeSessionAdvancesProgress=false;
    this.navigatorVisible=false;
    this.finishingSession=false;
    this.draftLabel='';
  }

  private toggleQuestionTranslation():void {
    if (this.isMockSession() || this.currentTranslationStem.length===0) return;
    this.showQuestionTranslation=!this.showQuestionTranslation;
  }

  private optionBackground(index:number):string {
    if (!this.answerLocked) return AppTheme.SURFACE;
    if (this.isMockSession()) return index===this.selectedIndex?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE;
    if (index===this.currentCorrectIndex) return AppTheme.SUCCESS_SOFT;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER_SOFT;
    return AppTheme.SURFACE;
  }

  private optionBorder(index:number):string {
    if (!this.answerLocked) return AppTheme.BORDER;
    if (this.isMockSession()) return index===this.selectedIndex?AppTheme.PRIMARY:AppTheme.BORDER;
    if (index===this.currentCorrectIndex) return AppTheme.SUCCESS;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER;
    return AppTheme.BORDER;
  }

  private optionText(index:number):string {
    if (!this.answerLocked) return AppTheme.TEXT;
    if (this.isMockSession()) return index===this.selectedIndex?AppTheme.PRIMARY:AppTheme.TEXT;
    if (index===this.currentCorrectIndex) return AppTheme.SUCCESS;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER;
    return AppTheme.TEXT;
  }

  private optionPrefix(index:number):string {
    if (index===0) return 'A';
    if (index===1) return 'B';
    if (index===2) return 'C';
    return 'D';
  }

  @Builder
  private Metric(value:string,label:string) {
    Column({space:4}) {
      Text(value)
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT)
        .maxLines(1)
        .textOverflow({overflow:TextOverflow.Ellipsis});
      Text(label)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT)
        .maxLines(1)
        .textOverflow({overflow:TextOverflow.Ellipsis});
    }
    .layoutWeight(1)
    .constraintSize({minHeight:70})
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }


  @Builder
  private TodayCard() {
    Column({space:14}) {
      Row() {
        Column({space:4}) {
          Text('Day '+this.selectedStudyDay+' / 21 · '+this.dayContextLabel(this.selectedStudyDay))
            .fontSize(AppTheme.META_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          Text(this.selectedDayTitle)
            .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(this.selectedDayFocus)
            .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start);
        Text('约 '+this.selectedDayMinutes+' min').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%').alignItems(VerticalAlign.Top);

      Text('当日任务 '+this.completedTasksCount()+'/3 已完成 · 完成后推进学习进度')
        .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.PRIMARY);
      Row({space:10}) {
        this.Metric(this.viewModel.skillLabel(this.progressWeakSkill),'当前薄弱点');
        this.Metric(String(this.progressReviewCount),'待复习错题');
        this.Metric(String(this.progressSlowCount),'做对但偏慢');
      }
      .width('100%');

      Row({space:10}) {
        Button((this.selectedVocabDone?'✓ ':'')+'高频词 '+this.selectedDayVocabularyCount+' 个',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(this.selectedDayVocabularyCount>0?AppTheme.PRIMARY:AppTheme.TERTIARY_TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.selectedDayVocabularyCount>0)
          .onClick(()=>this.openVocabulary());
        Button((this.selectedSentenceDone?'✓ ':'')+'阅读提速 '+this.selectedDaySentenceCount+' 句',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(this.selectedDaySentenceCount>0?AppTheme.PRIMARY:AppTheme.TERTIARY_TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.selectedDaySentenceCount>0)
          .onClick(()=>this.openSentenceDrills());
      }
      .width('100%');

      Text(this.selectedDayGuidance())
        .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);

    }
    .width('100%').padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({width:1,color:AppTheme.BORDER})
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private DayButton(day:number) {
    Button('Day '+day,{type:ButtonType.Normal})
      .layoutWeight(1)
      .height(40)
      .fontSize(AppTheme.META_SIZE)
      .fontWeight(day===this.selectedStudyDay?FontWeight.Bold:FontWeight.Regular)
      .fontColor(day===this.selectedStudyDay?AppTheme.TEXT_ON_PRIMARY:
        (day===this.progressCurrentDay?AppTheme.PRIMARY:AppTheme.TEXT))
      .backgroundColor(day===this.selectedStudyDay?AppTheme.PRIMARY:
        (day===this.progressCurrentDay?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE_SUBTLE))
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .onClick(()=>this.selectStudyDay(day));
  }

  @Builder
  private DaySelector() {
    Column({space:10}) {
      Row() {
        Text('选择训练日')
          .fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Blank();
        Text('当前进度 Day '+this.progressCurrentDay)
          .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(1);
        this.DayButton(2);
        this.DayButton(3);
        this.DayButton(4);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(5);
        this.DayButton(6);
        this.DayButton(7);
        this.DayButton(8);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(9);
        this.DayButton(10);
        this.DayButton(11);
        this.DayButton(12);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(13);
        this.DayButton(14);
        this.DayButton(15);
        this.DayButton(16);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(17);
        this.DayButton(18);
        this.DayButton(19);
        this.DayButton(20);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(21);
        Blank().layoutWeight(1);
        Blank().layoutWeight(1);
        Blank().layoutWeight(1);
      }
      .width('100%');

      Text('可自由复习或预习任意一天；只有完成当前进度日才会推进学习进度。')
        .width('100%').fontSize(AppTheme.META_SIZE)
        .lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
    }
    .width('100%').padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({width:1,color:AppTheme.BORDER})
    .borderRadius(AppTheme.CARD_RADIUS);
  }


  // Fixed chrome is a sibling of Scroll; only the central content pane scrolls.
  private hasFixedFooter():boolean {
    if (this.mode===ToeicPageMode.HOME) return this.viewModel.contentErrors().length===0;
    if (this.mode===ToeicPageMode.VOCABULARY) return this.selectedDayVocabularyCount>0 && !this.selectedVocabDone;
    if (this.mode===ToeicPageMode.SENTENCE) return this.selectedDaySentenceCount>0 && !this.selectedSentenceDone;
    return this.mode===ToeicPageMode.VOCABULARY_QUIZ ||
      this.mode===ToeicPageMode.MOCK_RESULT ||
      ((this.mode===ToeicPageMode.TRAINING || this.mode===ToeicPageMode.DIAGNOSTIC) &&
        this.currentQuestionId.length>0);
  }

  @Builder
  private FixedHeader() {
    Column() {
      if (this.mode===ToeicPageMode.HOME) {
          Row() {
            Column({space:4}) {
              Text('TOEIC')
                .fontSize(AppTheme.PAGE_TITLE_SIZE).lineHeight(AppTheme.PAGE_TITLE_LINE_HEIGHT)
                .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Text('Reading 350+ · 三周高效备考')
                .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start);
            Text('首批词库 '+this.viewModel.vocabularyCount())
              .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%').alignItems(VerticalAlign.Center);
      } else if (this.mode===ToeicPageMode.VOCABULARY) {
        DeepPageHeader({
          title:'Day '+this.selectedStudyDay+' 高频词',
          subtitle:this.selectedDayTitle+' · '+this.selectedDayVocabularyCount+' 个',
          onBack:()=>this.cancelSession()
        });
      } else if (this.mode===ToeicPageMode.VOCABULARY_QUIZ) {
        DeepPageHeader({
          title:'词汇检索测验',
          subtitle:this.quizModeLabel+' · '+(this.quizPosition+1)+' / '+this.quizQuestions.length,
          onBack:()=>{this.mode=ToeicPageMode.VOCABULARY;}
        });
      } else if (this.mode===ToeicPageMode.SENTENCE) {
        DeepPageHeader({
          title:'Day '+this.selectedStudyDay+' 阅读提速',
          subtitle:this.selectedDayTitle+' · '+this.selectedDaySentenceCount+' 句',
          onBack:()=>this.cancelSession()
        });
      } else if (this.mode===ToeicPageMode.MOCK_RESULT) {
        DeepPageHeader({
          title:'Day '+this.mockResultDay+' 模考结果',
          subtitle:this.mockResultDay===19?'第二次完整 Reading 模考':'第一次完整 Reading 模考',
          onBack:()=>this.leaveMockResult()
        });
      } else if (this.currentQuestionId.length>0) {
        DeepPageHeader({
          title:this.mode===ToeicPageMode.DIAGNOSTIC?'Reading 水平诊断':
            (this.isMockSession()?'Reading 完整模考':'今日训练'),
          subtitle:String(this.currentIndex+1)+' / '+this.questions.length+' · '+
            this.viewModel.partLabel(this.currentPart),
          trailingText:this.isMockSession()?this.clockLabel():'建议 '+this.currentRecommendedSeconds+'s',
          onBack:()=>this.cancelSession()
        });
      }
    }
    .width('100%')
    .constraintSize({maxWidth:this.mode===ToeicPageMode.HOME?
      AppTheme.CONTENT_STANDARD_MAX_WIDTH:AppTheme.CONTENT_NARROW_MAX_WIDTH})
    .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
      right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
      top:this.mode===ToeicPageMode.HOME?20:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:8})
    .backgroundColor(AppTheme.BACKGROUND);
  }

  @Builder
  private FixedFooter() {
    Column() {
      if (this.mode===ToeicPageMode.HOME) {
        Button((this.selectedTrainingDone?'✓ ':'')+this.trainingButtonLabel(),{type:ButtonType.Normal})
          .width('100%').height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
          .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.startTraining());
      } else if (this.mode===ToeicPageMode.VOCABULARY) {
        Button('完成今日词汇学习',{type:ButtonType.Normal})
          .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.TEXT_ON_PRIMARY).backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>{void this.finishDayTask('vocabulary');});
      } else if (this.mode===ToeicPageMode.SENTENCE) {
        Button('完成今日拆句训练',{type:ButtonType.Normal})
          .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.TEXT_ON_PRIMARY).backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>{void this.finishDayTask('sentence');});
      } else if (this.mode===ToeicPageMode.VOCABULARY_QUIZ) {
        Button(this.quizPosition+1>=this.quizQuestions.length?'完成词汇测验':'下一题',
          {type:ButtonType.Normal})
          .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.TEXT_ON_PRIMARY).backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.quizSelectedIndex>=0)
          .onClick(()=>this.nextVocabularyQuiz());
      } else if (this.mode===ToeicPageMode.MOCK_RESULT) {
        Button('返回训练首页',{type:ButtonType.Normal})
          .width('100%').height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
          .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.leaveMockResult());
      } else if (this.currentQuestionId.length>0) {
        Row({space:10}) {
          Button('上一题',{type:ButtonType.Normal})
            .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
            .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.PRIMARY)
            .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(this.currentIndex>0)
            .onClick(()=>this.previousQuestion());
          Button(this.currentIndex+1>=this.questions.length?(this.isMockSession()?'提交模考':'完成本轮'):'下一题',{type:ButtonType.Normal})
            .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
            .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
            .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(this.isMockSession() || this.answerLocked)
            .onClick(()=>this.nextQuestion());
        }
        .width('100%');
      }
    }
    .width('100%')
    .constraintSize({maxWidth:this.mode===ToeicPageMode.HOME?
      AppTheme.CONTENT_STANDARD_MAX_WIDTH:AppTheme.CONTENT_NARROW_MAX_WIDTH})
    .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
      right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),top:8,
      bottom:AppTheme.DEEP_PAGE_BOTTOM_PADDING})
    .backgroundColor(AppTheme.BACKGROUND);
  }

  @Builder
  private HomeContent() {
    Scroll() {
      Column({space:AppTheme.SECTION_GAP_STANDARD}) {
        if (this.viewModel.contentErrors().length>0) {
          Text('内容校验未通过，正式训练内容已暂停。')
            .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.DANGER)
            .padding(AppTheme.CARD_PADDING_COMPACT).backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
        } else {
          if (this.draftLabel.length>0) {
            Column({space:10}) {
              Text('继续未完成训练')
                .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
                .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Text(this.draftLabel)
                .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
              Row({space:10}) {
                Button('继续作答',{type:ButtonType.Normal})
                  .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS).fontColor(AppTheme.TEXT_ON_PRIMARY)
                  .onClick(()=>this.resumeDraft());
                Button('放弃本轮',{type:ButtonType.Normal})
                  .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS).fontColor(AppTheme.PRIMARY)
                  .onClick(()=>this.discardSavedDraft());
              }
              .width('100%');
            }
            .width('100%').padding(AppTheme.CARD_PADDING)
            .backgroundColor(AppTheme.CARD_SURFACE)
            .border({width:1,color:AppTheme.BORDER})
            .borderRadius(AppTheme.CARD_RADIUS);
          }
          this.TodayCard();
          Button(this.showFullPlan?'收起 21 天计划':'展开 21 天计划（可复习或预习）',
            {type:ButtonType.Normal})
            .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>{this.showFullPlan=!this.showFullPlan;});
          if (this.showFullPlan) { this.DaySelector(); }
          if (this.viewModel.supplementaryReadingQuestions().length>0) {
            Button('Part 7 双篇 / 三篇加练',{type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.startSupplementaryReading());
          }
          Button('标准水平诊断 · 12 题',{type:ButtonType.Normal})
            .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.startStandardDiagnostic());
          Text('标准诊断不影响当前 Day 进度；基础快速诊断仍是 Day 1 入口。')
            .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
          if (!this.progressDiagnosticCompleted && this.selectedStudyDay!==1) {
            Text('建议先完成 Day 1 快速诊断，但你也可以直接进入当前选择的训练日。')
              .width('100%').fontSize(AppTheme.META_SIZE)
              .lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT)
              .padding(AppTheme.CARD_PADDING_COMPACT)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          }
          Column({space:10}) {
            Text('当前学习状态')
              .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
              .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            Row({space:10}) {
              this.Metric(String(this.progressAnswered),'累计答题');
              this.Metric(String(this.progressCorrect),'累计正确');
              this.Metric(this.progressAccuracy,'正确率');
            }
            .width('100%');
          }
          .width('100%').padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);

        }

        if (this.recentReports.length>0) {
          Column({space:8}) {
            Text('最近训练记录')
              .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
              .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            ForEach(this.recentReports,(report:ToeicSessionReport)=>{
              Column({space:4}) {
                Text(this.lastSessionHeadline(report))
                  .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.TEXT);
                Text('P5 '+report.part5Correct+'/'+report.part5Answered+
                  ' · P6 '+report.part6Correct+'/'+report.part6Answered+
                  ' · P7 '+report.part7Correct+'/'+report.part7Answered)
                  .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
                Text('平均用时：P5 '+(report.part5Answered>0?
                  Math.round(report.part5Seconds/report.part5Answered)+'s':'--')+
                  ' · P6 '+(report.part6Answered>0?
                    Math.round(report.part6Seconds/report.part6Answered)+'s':'--')+
                  ' · P7 '+(report.part7Answered>0?
                    Math.round(report.part7Seconds/report.part7Answered)+'s':'--'))
                  .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%');
            },(report:ToeicSessionReport)=>String(report.completedAtMs));
            Text('正确率为练习原始得分，不代表官方换算分。')
              .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%').padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
        }

        if (this.mockReports.length>0) {
          Column({space:9}) {
            Text('完整模考历史')
              .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
              .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            if (this.mockComparisonLabel().length>0) {
              Text(this.mockComparisonLabel())
                .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.PRIMARY);
            }
            ForEach(this.mockReports,(report:ToeicMockReport)=>{
              Row({space:8}) {
                Text('Day '+report.day)
                  .fontSize(AppTheme.BODY_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
                Blank();
                Text(report.correctCount+'/'+report.totalCount+' · 未答 '+
                  (report.totalCount-report.answeredCount)+' · '+
                  Math.round(report.elapsedSeconds/60)+' 分钟')
                  .fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%');
            },(report:ToeicMockReport)=>String(report.completedAtMs));
          }
          .width('100%').padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
        }

        Column({space:6}) {
          Text('训练原则').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('高频优先 · 速度优先 · 基础分优先 · 错因优先')
            .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
          Text('首期开放 Reading；底层题目与进度模型已兼容后续 Listening Part 1–4。')
            .fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%').alignItems(HorizontalAlign.Start).padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_STANDARD_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),top:8,bottom:8});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private VocabularyContent(items:ToeicVocabularyItem[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        Row({space:8}) {
          Button('词义测验',{type:ButtonType.Normal})
            .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.startVocabularyQuiz(ToeicVocabularyQuizMode.MEANING));
          Button('搭配测验',{type:ButtonType.Normal})
            .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.startVocabularyQuiz(ToeicVocabularyQuizMode.COLLOCATION));
          Button('同义测验',{type:ButtonType.Normal})
            .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.startVocabularyQuiz(ToeicVocabularyQuizMode.PARAPHRASE));
        }
        .width('100%');
        Text('选择一种检索测验，答题结果会自动安排到期复习。')
          .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        if (this.pronunciationMessage.length>0) {
          Text(this.pronunciationMessage)
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT)
            .padding(AppTheme.CARD_PADDING_COMPACT)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
        }
        ForEach(items,(item:ToeicVocabularyItem)=>{
          Column({space:8}) {
            Row() {
              Text(item.word)
                .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Text('  '+item.partOfSpeech)
                .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(item.level)
                .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.PRIMARY)
                .padding({left:8,right:8,top:4,bottom:4})
                .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CHIP_RADIUS);
            }
            .width('100%');

            Row({space:10}) {
              Text('美 '+item.ipa)
                .layoutWeight(1)
                .fontSize(AppTheme.BODY_SIZE)
                .fontColor(AppTheme.SUBTEXT);
              Button('发音',{type:ButtonType.Normal})
                .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .fontSize(AppTheme.ACTION_TEXT_SIZE)
                .fontColor(AppTheme.PRIMARY)
                .backgroundColor(AppTheme.PRIMARY_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(()=>{ void this.pronounce(item); });
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Button(this.revealedWordIds.indexOf(item.id)>=0?'收起词义':'查看词义与搭配',
              {type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.toggleWordReveal(item.id));
            if (this.revealedWordIds.indexOf(item.id)>=0) {
              Text(item.meaning)
                .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.TEXT);
              Text('场景：'+item.scenario)
                .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
              if (item.exampleSentence.length>0) {
                Text('例句：'+item.exampleSentence)
                  .width('100%').fontSize(AppTheme.BODY_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
              }
              if (item.collocations.length>0) {
                Text('搭配：'+item.collocations.join(' · '))
                  .width('100%').fontSize(AppTheme.BODY_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.PRIMARY);
              }
              if (item.paraphrases.length>0) {
                Text('同义：'+item.paraphrases.join(' · '))
                  .width('100%').fontSize(AppTheme.META_SIZE)
                  .lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
              }
              Row({space:10}) {
                Button('记住了',{type:ButtonType.Normal})
                  .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
                  .onClick(()=>{void this.recordWordRecall(item,true);});
                Button('没记住',{type:ButtonType.Normal})
                  .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
                  .onClick(()=>{void this.recordWordRecall(item,false);});
              }
              .width('100%');
              if (this.lastReviewedWordId===item.id) {
                Text(this.vocabularyFeedback)
                  .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
              }
            }
          }
          .width('100%').padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.CARD_SURFACE)
          .border({width:1,color:AppTheme.BORDER})
          .borderRadius(AppTheme.CARD_RADIUS);
        },(item:ToeicVocabularyItem)=>item.id);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_TOP_PADDING});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private VocabularyQuizContent() {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        Column({space:10}) {
          Text(this.quizStem)
            .width('100%').fontSize(AppTheme.QUESTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Button({type:ButtonType.Normal}) {
            Text('A. '+this.quizOptionA)
              .width('100%').textAlign(TextAlign.Start)
              .fontSize(AppTheme.FORM_TEXT_SIZE)
              .fontColor(AppTheme.TEXT)
              .padding({left:14,right:14,top:12,bottom:12});
          }
          .width('100%').constraintSize({minHeight:50}).padding(0)
          .backgroundColor(this.quizSelectedIndex===0?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE)
          .border({width:1,color:this.quizSelectedIndex===0?AppTheme.PRIMARY:AppTheme.BORDER})
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.answerVocabularyQuiz(0));
          Button({type:ButtonType.Normal}) {
            Text('B. '+this.quizOptionB)
              .width('100%').textAlign(TextAlign.Start)
              .fontSize(AppTheme.FORM_TEXT_SIZE)
              .fontColor(AppTheme.TEXT)
              .padding({left:14,right:14,top:12,bottom:12});
          }
          .width('100%').constraintSize({minHeight:50}).padding(0)
          .backgroundColor(this.quizSelectedIndex===1?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE)
          .border({width:1,color:this.quizSelectedIndex===1?AppTheme.PRIMARY:AppTheme.BORDER})
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.answerVocabularyQuiz(1));
          Button({type:ButtonType.Normal}) {
            Text('C. '+this.quizOptionC)
              .width('100%').textAlign(TextAlign.Start)
              .fontSize(AppTheme.FORM_TEXT_SIZE)
              .fontColor(AppTheme.TEXT)
              .padding({left:14,right:14,top:12,bottom:12});
          }
          .width('100%').constraintSize({minHeight:50}).padding(0)
          .backgroundColor(this.quizSelectedIndex===2?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE)
          .border({width:1,color:this.quizSelectedIndex===2?AppTheme.PRIMARY:AppTheme.BORDER})
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.answerVocabularyQuiz(2));
          Button({type:ButtonType.Normal}) {
            Text('D. '+this.quizOptionD)
              .width('100%').textAlign(TextAlign.Start)
              .fontSize(AppTheme.FORM_TEXT_SIZE)
              .fontColor(AppTheme.TEXT)
              .padding({left:14,right:14,top:12,bottom:12});
          }
          .width('100%').constraintSize({minHeight:50}).padding(0)
          .backgroundColor(this.quizSelectedIndex===3?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE)
          .border({width:1,color:this.quizSelectedIndex===3?AppTheme.PRIMARY:AppTheme.BORDER})
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.answerVocabularyQuiz(3));
          if (this.quizSelectedIndex>=0) {
            Text(this.quizSelectedIndex===this.quizAnswerIndex?'回答正确':'需要巩固')
              .width('100%').fontSize(AppTheme.CARD_TITLE_SIZE)
              .fontColor(this.quizSelectedIndex===this.quizAnswerIndex?AppTheme.SUCCESS:AppTheme.DANGER);
            Text(this.quizExplanation)
              .width('100%').fontSize(AppTheme.BODY_SIZE)
              .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
          }
          Text('本轮已答对 '+this.quizCorrectCount+'/'+
            (this.quizPosition+(this.quizSelectedIndex>=0?1:0))+'；错误词进入短期复习。')
            .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_TOP_PADDING});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private SentenceContent(items:ToeicSentenceDrill[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        Column({space:8}) {
          Text('训练方法')
            .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('先在几秒内抓主干，再看修饰成分。目标不是全文翻译，而是快速识别谁做什么。')
            .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CARD_RADIUS);

        ForEach(items,(item:ToeicSentenceDrill)=>{
          Column({space:8}) {
            Text(item.sentence)
              .width('100%').fontSize(AppTheme.READING_BODY_SIZE)
              .lineHeight(AppTheme.READING_BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
            Button(this.revealedSentenceIds.indexOf(item.id)>=0?'收起解析':'查看主干与译文',
              {type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.toggleSentenceReveal(item.id));
            if (this.revealedSentenceIds.indexOf(item.id)>=0) {
              Text('译：'+item.translation)
                .width('100%').fontSize(AppTheme.BODY_SIZE)
                .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
              Text('主干：'+item.core)
                .width('100%').fontSize(AppTheme.BODY_SIZE)
                .fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
              Text('重点：'+item.focus)
                .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
              Text(item.explanation)
                .width('100%').fontSize(AppTheme.BODY_SIZE)
                .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
            }
          }
          .width('100%').padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.CARD_SURFACE)
          .border({width:1,color:AppTheme.BORDER})
          .borderRadius(AppTheme.CARD_RADIUS);
        },(item:ToeicSentenceDrill)=>item.id);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_TOP_PADDING});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private MockResultContent() {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        Column({space:10}) {
          Text(this.mockResultCorrect+' / '+this.mockResultTotal)
            .width('100%').fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('正确率 '+(this.mockResultTotal>0?
            Math.round(this.mockResultCorrect*100/this.mockResultTotal)+'%':'--')+
            ' · 用时 '+Math.max(1,Math.round(this.mockElapsedSeconds/60))+' min'+
            ' · 已答 '+this.mockResultAnswered+' · 未答 '+this.mockResultUnanswered)
            .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CARD_RADIUS);

        Row({space:10}) {
          this.Metric(this.mockPart5Correct+' / '+this.mockPart5Total,'Part 5');
          this.Metric(this.mockPart6Correct+' / '+this.mockPart6Total,'Part 6');
          this.Metric(this.mockPart7Correct+' / '+this.mockPart7Total,'Part 7');
        }
        .width('100%');

        Column({space:8}) {
          Text('复盘建议').width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('错题已经进入待复习队列；后续训练会继续按错题、慢题与薄弱技能做针对性巩固。')
            .width('100%').fontSize(AppTheme.BODY_SIZE)
            .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);

      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_TOP_PADDING});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private QuestionContent() {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        Column({space:12}) {
          if (this.isMockSession()) {
            Row({space:10}) {
              Text('剩余时间 '+this.clockLabel())
                .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold)
                .fontColor(this.mockCountdownSeconds<=300?AppTheme.DANGER:AppTheme.PRIMARY);
              Blank();
              Text('已答 '+this.attempts.length+' / '+this.questions.length)
                .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%').padding(AppTheme.CARD_PADDING_COMPACT)
            .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
            Row({space:10}) {
              Button(this.isQuestionMarked(this.currentQuestionId)?'取消标记':'标记此题',
                {type:ButtonType.Normal})
                .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(()=>this.toggleQuestionMark());
              Button(this.navigatorVisible?'收起题号导航':'展开题号导航',{type:ButtonType.Normal})
                .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
                .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(()=>{this.navigatorVisible=!this.navigatorVisible;});
            }
            .width('100%');
            if (this.navigatorVisible) {
              Flex({wrap:FlexWrap.Wrap,space:{main:LengthMetrics.vp(6),cross:LengthMetrics.vp(6)}}) {
                ForEach(this.questions,(question:ToeicQuestion,index:number)=>{
                  Button((this.isQuestionMarked(question.id)?'★':'')+String(index+1),
                    {type:ButtonType.Normal})
                    .width(48).height(42).fontSize(AppTheme.META_SIZE)
                    .fontColor(index===this.currentIndex?AppTheme.TEXT_ON_PRIMARY:AppTheme.PRIMARY)
                    .backgroundColor(index===this.currentIndex?AppTheme.PRIMARY:
                      (this.sessionAttempt(question.id)!==null?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE_SUBTLE))
                    .borderRadius(AppTheme.CONTROL_RADIUS)
                    .onClick(()=>this.jumpToQuestion(index));
                },(question:ToeicQuestion)=>question.id);
              }
              .width('100%');
            }
            Text('可跳过、返回修改或标记题目；剩余时间结束时自动交卷。')
              .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
            Button('提前提交整场模考',{type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT).fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.confirmMockSubmission());
          }
          Row() {
            Text(this.viewModel.skillLabel(this.currentSkill))
              .fontSize(AppTheme.META_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
              .padding({left:9,right:9,top:5,bottom:5}).backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
            Blank();
            Text(this.currentScoreValue===ToeicScoreValue.MUST_GET?'基础分优先':
              (this.currentScoreValue===ToeicScoreValue.OPTIONAL?'难题可取舍':'正常作答'))
              .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          if (!this.isMockSession() && this.currentAttemptCount>0) {
            Row({space:8}) {
              Text('已做 '+this.currentAttemptCount+' 次')
                .fontSize(AppTheme.META_SIZE)
                .fontColor(AppTheme.SUBTEXT)
                .padding({left:8,right:8,top:4,bottom:4})
                .backgroundColor(AppTheme.SURFACE_SUBTLE)
                .borderRadius(AppTheme.CHIP_RADIUS);
              if (this.currentWrongCount>0) {
                Text('错 '+this.currentWrongCount+' 次')
                  .fontSize(AppTheme.META_SIZE)
                  .fontColor(AppTheme.DANGER)
                  .padding({left:8,right:8,top:4,bottom:4})
                  .backgroundColor(AppTheme.DANGER_SOFT)
                  .borderRadius(AppTheme.CHIP_RADIUS);
              }
            }
            .width('100%');
          }

          if (this.currentPassage.length>0) {
            if (this.currentGroupCount>1) {
              Text('共用阅读材料 · 本组第 '+this.currentGroupPosition+'/'+this.currentGroupCount+' 题')
                .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.PRIMARY);
            }
            ForEach(this.currentPassageBlocks,(block:string,index:number)=>{
              Text(block)
                .width('100%').fontSize(AppTheme.READING_BODY_SIZE)
                .lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
                .fontColor(AppTheme.TEXT).padding(AppTheme.CARD_PADDING)
                .backgroundColor(AppTheme.SURFACE_SUBTLE)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            },(block:string,index:number)=>String(index));
          }

          Text(this.currentStem)
            .width('100%').fontSize(AppTheme.QUESTION_TEXT_SIZE).lineHeight(AppTheme.QUESTION_TEXT_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);

          Column({space:9}) {
            Button({type:ButtonType.Normal}) {
              Row({space:8}) {
                Text('A.')
                  .width(22)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.optionText(0));
                Text(this.currentOptionA)
                  .layoutWeight(1)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                  .fontColor(this.optionText(0))
                  .textAlign(TextAlign.Start);
              }
              .width('100%')
              .constraintSize({minHeight:50})
              .alignItems(VerticalAlign.Center)
              .padding({left:14,right:14,top:12,bottom:12});
            }
            .width('100%')
            .constraintSize({minHeight:50})
            .padding(0)
            .backgroundColor(this.optionBackground(0))
            .border({width:1,color:this.optionBorder(0)})
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.chooseAnswer(0));
            Button({type:ButtonType.Normal}) {
              Row({space:8}) {
                Text('B.')
                  .width(22)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.optionText(1));
                Text(this.currentOptionB)
                  .layoutWeight(1)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                  .fontColor(this.optionText(1))
                  .textAlign(TextAlign.Start);
              }
              .width('100%')
              .constraintSize({minHeight:50})
              .alignItems(VerticalAlign.Center)
              .padding({left:14,right:14,top:12,bottom:12});
            }
            .width('100%')
            .constraintSize({minHeight:50})
            .padding(0)
            .backgroundColor(this.optionBackground(1))
            .border({width:1,color:this.optionBorder(1)})
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.chooseAnswer(1));
            Button({type:ButtonType.Normal}) {
              Row({space:8}) {
                Text('C.')
                  .width(22)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.optionText(2));
                Text(this.currentOptionC)
                  .layoutWeight(1)
                  .fontSize(AppTheme.FORM_TEXT_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                  .fontColor(this.optionText(2))
                  .textAlign(TextAlign.Start);
              }
              .width('100%')
              .constraintSize({minHeight:50})
              .alignItems(VerticalAlign.Center)
              .padding({left:14,right:14,top:12,bottom:12});
            }
            .width('100%')
            .constraintSize({minHeight:50})
            .padding(0)
            .backgroundColor(this.optionBackground(2))
            .border({width:1,color:this.optionBorder(2)})
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(()=>this.chooseAnswer(2));
            if (this.currentOptionCount>3) {
              Button({type:ButtonType.Normal}) {
                Row({space:8}) {
                  Text('D.')
                    .width(22)
                    .fontSize(AppTheme.FORM_TEXT_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.optionText(3));
                  Text(this.currentOptionD)
                    .layoutWeight(1)
                    .fontSize(AppTheme.FORM_TEXT_SIZE)
                    .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                    .fontColor(this.optionText(3))
                    .textAlign(TextAlign.Start);
                }
                .width('100%')
                .constraintSize({minHeight:50})
                .alignItems(VerticalAlign.Center)
                .padding({left:14,right:14,top:12,bottom:12});
              }
              .width('100%')
              .constraintSize({minHeight:50})
              .padding(0)
              .backgroundColor(this.optionBackground(3))
              .border({width:1,color:this.optionBorder(3)})
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.chooseAnswer(3));
            }
          }
          .width('100%');

          if (!this.isMockSession() && this.currentTranslationStem.length>0) {
            Button(this.showQuestionTranslation?'收起中文翻译':'查看中文翻译',{type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT)
              .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.PRIMARY)
              .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.toggleQuestionTranslation());

            if (this.showQuestionTranslation) {
              Column({space:8}) {
                Text('中文翻译 · 辅助理解')
                  .width('100%').fontSize(AppTheme.META_SIZE)
                  .fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
                if (this.currentTranslationPassage.length>0) {
                  Text(this.currentTranslationPassage)
                    .width('100%').fontSize(AppTheme.BODY_SIZE)
                    .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
                }
                Text(this.currentTranslationStem)
                  .width('100%').fontSize(AppTheme.BODY_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Row({space:8}) {
                  Text('A.').width(22).fontSize(AppTheme.BODY_SIZE)
                    .fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
                  Text(this.currentTranslationOptionA).layoutWeight(1)
                    .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .width('100%').alignItems(VerticalAlign.Top);
                Row({space:8}) {
                  Text('B.').width(22).fontSize(AppTheme.BODY_SIZE)
                    .fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
                  Text(this.currentTranslationOptionB).layoutWeight(1)
                    .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .width('100%').alignItems(VerticalAlign.Top);
                Row({space:8}) {
                  Text('C.').width(22).fontSize(AppTheme.BODY_SIZE)
                    .fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
                  Text(this.currentTranslationOptionC).layoutWeight(1)
                    .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .width('100%').alignItems(VerticalAlign.Top);
                if (this.currentOptionCount>3) {
                  Row({space:8}) {
                    Text('D.').width(22).fontSize(AppTheme.BODY_SIZE)
                      .fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
                    Text(this.currentTranslationOptionD).layoutWeight(1)
                      .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT)
                      .fontColor(AppTheme.SUBTEXT);
                  }
                  .width('100%').alignItems(VerticalAlign.Top);
                }
              }
              .width('100%').padding(AppTheme.CARD_PADDING)
              .backgroundColor(AppTheme.SURFACE_SUBTLE)
              .border({width:1,color:AppTheme.BORDER})
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }
          }

          if (this.answerLocked) {
            if (this.isMockSession()) {
              Column({space:7}) {
                Text('已记录本题答案')
                  .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.PRIMARY);
                Text('完整模考过程中不显示对错与解析，结束后统一查看结果。')
                  .width('100%').fontSize(AppTheme.BODY_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%').padding(AppTheme.CARD_PADDING)
              .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
            } else {
              Column({space:7}) {
                Text(this.answerCorrect?'✓ 判断正确':'× 这题需要再巩固')
                  .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold)
                  .fontColor(this.answerCorrect?AppTheme.SUCCESS:AppTheme.DANGER);
                Text(this.currentExplanation)
                  .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
                if (this.currentEvidence.length>0) {
                  Text('证据：'+this.currentEvidence)
                    .width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
                }
                if (this.currentParaphrase.length>0) {
                  Text('替换关系：'+this.currentParaphrase)
                    .width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.PRIMARY);
                }
              }
              .width('100%').padding(AppTheme.CARD_PADDING)
              .backgroundColor(this.answerCorrect?AppTheme.SUCCESS_SOFT:AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }
          }

        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_TOP_PADDING});
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  build() {
    Column() {
      this.FixedHeader();
      if (this.mode===ToeicPageMode.HOME) {
        this.HomeContent();
      } else if (this.mode===ToeicPageMode.VOCABULARY) {
        this.VocabularyContent(
          this.viewModel.vocabularyForDay(this.effectiveStudyDay())
        );
      } else if (this.mode===ToeicPageMode.VOCABULARY_QUIZ) {
        this.VocabularyQuizContent();
      } else if (this.mode===ToeicPageMode.SENTENCE) {
        this.SentenceContent(
          this.viewModel.sentenceDrillsForDay(this.effectiveStudyDay())
        );
      } else if (this.mode===ToeicPageMode.MOCK_RESULT) {
        this.MockResultContent();
      } else if (this.currentQuestionId.length>0) {
        this.QuestionContent();
      }
      if (this.hasFixedFooter()) {
        this.FixedFooter();
      }
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center).backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue,newValue)=>{
      this.availableWidthVp=LayoutPolicy.areaLengthToVp(newValue.width,this.availableWidthVp);
    });
  }
}
