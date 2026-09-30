import { LayoutPolicy } from '../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../common/theme/AppTheme';
import { DeepPageHeader } from '../../components/navigation/DeepPageHeader';
import { ToeicLearningSnapshot, ToeicPart, ToeicPerformance, ToeicQuestion, ToeicQuestionAttempt, ToeicScoreValue, ToeicSentenceDrill, ToeicSkill, ToeicVocabularyItem } from '../domain/ToeicModels';
import { ToeicCoachViewModel } from './ToeicCoachViewModel';
import { ToeicPronunciationStatus } from '../application/ToeicPronunciationService';

enum ToeicPageMode { HOME='HOME', DIAGNOSTIC='DIAGNOSTIC', TRAINING='TRAINING', VOCABULARY='VOCABULARY', SENTENCE='SENTENCE' }

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
  @State private activeSessionDay:number=0;
  @State private activeSessionAdvancesProgress:boolean=false;
  @State private currentQuestionId:string='';
  @State private currentPassage:string='';
  @State private currentStem:string='';
  @State private currentOptionCount:number=0;
  @State private currentOptionA:string='';
  @State private currentOptionB:string='';
  @State private currentOptionC:string='';
  @State private currentOptionD:string='';
  @State private currentCorrectIndex:number=-1;
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
    if (this.selectedStudyDay<=0) this.selectedStudyDay=this.viewModel.snapshot().currentDay;
    this.loadStudyDay(this.selectedStudyDay);
    this.refreshRevision++;
  }

  private currentQuestionForAttempt():ToeicQuestion|null {
    if (this.currentQuestionId.length===0) return null;
    for (let question of this.questions) {
      if (question.id===this.currentQuestionId) return question;
    }
    return null;
  }

  private loadQuestion(index:number):boolean {
    if (index<0 || index>=this.questions.length) return false;
    let question=this.questions[index];
    this.currentQuestionId=question.id;
    this.currentPassage=question.passage;
    this.currentStem=question.stem;
    this.currentOptionCount=question.options.length;
    this.currentOptionA=question.options.length>0?question.options[0]:'';
    this.currentOptionB=question.options.length>1?question.options[1]:'';
    this.currentOptionC=question.options.length>2?question.options[2]:'';
    this.currentOptionD=question.options.length>3?question.options[3]:'';
    this.currentCorrectIndex=question.correctIndex;
    this.currentExplanation=question.explanation;
    this.currentEvidence=question.evidence;
    this.currentParaphrase=question.paraphrase;
    this.currentRecommendedSeconds=question.recommendedSeconds;
    this.currentPart=question.part;
    this.currentSkill=question.skill;
    this.currentScoreValue=question.scoreValue;
    return true;
  }

  private clearQuestionSnapshot():void {
    this.currentQuestionId='';
    this.currentPassage='';
    this.currentStem='';
    this.currentOptionCount=0;
    this.currentOptionA='';
    this.currentOptionB='';
    this.currentOptionC='';
    this.currentOptionD='';
    this.currentCorrectIndex=-1;
    this.currentExplanation='';
    this.currentEvidence='';
    this.currentParaphrase='';
    this.currentRecommendedSeconds=0;
    this.currentPart=ToeicPart.PART_5;
    this.currentSkill=ToeicSkill.WORD_FORM;
    this.currentScoreValue=ToeicScoreValue.MUST_GET;
  }

  private effectiveStudyDay():number {
    if (this.selectedStudyDay>0) return this.selectedStudyDay;
    return this.viewModel.snapshot().currentDay;
  }

  private loadStudyDay(day:number):void {
    let plan=this.viewModel.planForDay(day);
    this.selectedDayTitle=this.selectedDayTitle;
    this.selectedDayFocus=this.selectedDayFocus;
    this.selectedDayMinutes=this.selectedDayMinutes;
    this.selectedDayVocabularyCount=this.selectedDayVocabularyCount;
    this.selectedDaySentenceCount=this.selectedDaySentenceCount;
  }

  private selectStudyDay(day:number):void {
    if (day<1 || day>7) return;
    this.selectedStudyDay=day;
    this.loadStudyDay(day);
    this.pronunciationMessage='';
  }

  private dayContextLabel(day:number,currentDay:number):string {
    if (day===currentDay) return '当前进度';
    if (day<currentDay) return '复习';
    return '预习';
  }

  private startDiagnostic():void {
    this.activeSessionDay=1;
    this.activeSessionAdvancesProgress=true;
    this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.diagnosticQuestions());
  }

  private startTraining():void {
    let day=this.effectiveStudyDay();
    if (day===1) {
      this.activeSessionDay=1;
      this.activeSessionAdvancesProgress=!this.viewModel.snapshot().diagnosticCompleted;
      this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.diagnosticQuestions());
      return;
    }
    this.activeSessionDay=day;
    this.activeSessionAdvancesProgress=day===this.viewModel.snapshot().currentDay;
    this.startSession(ToeicPageMode.TRAINING,this.viewModel.dailyQuestionsForDay(day));
  }

  private openVocabulary():void { this.pronunciationMessage=''; this.mode=ToeicPageMode.VOCABULARY; }
  private openSentenceDrills():void { this.mode=ToeicPageMode.SENTENCE; }

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

  private startSession(mode:ToeicPageMode,questions:ToeicQuestion[]):void {
    if (questions.length===0) return;
    this.questions=questions;
    this.currentIndex=0;
    this.selectedIndex=-1;
    this.answerLocked=false;
    this.answerCorrect=false;
    this.questionStartedAtMs=Date.now();
    this.attempts=[];
    this.loadQuestion(0);
    this.mode=mode;
  }

  private cancelSession():void {
    this.mode=ToeicPageMode.HOME;
    this.questions=[];
    this.attempts=[];
    this.answerLocked=false;
    this.selectedIndex=-1;
    this.clearQuestionSnapshot();
  }

  private chooseAnswer(index:number):void {
    if (this.answerLocked) return;
    let question=this.currentQuestionForAttempt();
    if (question===null || question.id!==this.currentQuestionId) return;
    let elapsed=Math.max(1,Math.round((Date.now()-this.questionStartedAtMs)/1000));
    let attempt=this.viewModel.createAttempt(question,index,elapsed);
    this.attempts.push(attempt);
    this.selectedIndex=index;
    this.answerCorrect=attempt.correct;
    this.answerLocked=true;
  }

  private nextQuestion():void {
    if (!this.answerLocked) return;
    let nextIndex=this.currentIndex+1;
    if (nextIndex>=this.questions.length) { void this.finishSession(); return; }
    this.currentIndex=nextIndex;
    this.selectedIndex=-1;
    this.answerLocked=false;
    this.answerCorrect=false;
    this.questionStartedAtMs=Date.now();
    this.loadQuestion(nextIndex);
  }

  private async finishSession():Promise<void> {
    let advanceProgress=this.activeSessionAdvancesProgress;
    await this.viewModel.completeSession(
      this.attempts,
      this.mode===ToeicPageMode.DIAGNOSTIC,
      advanceProgress
    );
    if (advanceProgress) {
      this.selectedStudyDay=this.viewModel.snapshot().currentDay;
      this.loadStudyDay(this.selectedStudyDay);
    }
    this.refreshRevision++; this.mode=ToeicPageMode.HOME; this.questions=[]; this.attempts=[];
    this.answerLocked=false; this.selectedIndex=-1;
    this.clearQuestionSnapshot();
    this.activeSessionDay=0; this.activeSessionAdvancesProgress=false;
  }

  private optionBackground(index:number):string {
    if (!this.answerLocked) return AppTheme.SURFACE;
    if (index===this.currentCorrectIndex) return AppTheme.SUCCESS_SOFT;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER_SOFT;
    return AppTheme.SURFACE;
  }

  private optionBorder(index:number):string {
    if (!this.answerLocked) return AppTheme.BORDER;
    if (index===this.currentCorrectIndex) return AppTheme.SUCCESS;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER;
    return AppTheme.BORDER;
  }

  private optionText(index:number):string {
    if (!this.answerLocked) return AppTheme.TEXT;
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
  private TodayCard(snapshot:ToeicLearningSnapshot,selectedDay:number) {
    Column({space:14}) {
      Row() {
        Column({space:4}) {
          Text('Day '+selectedDay+' / 21 · '+this.dayContextLabel(selectedDay,snapshot.currentDay))
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

      Row({space:10}) {
        this.Metric(this.viewModel.skillLabel(snapshot.weakSkill),'当前薄弱点');
        this.Metric(String(snapshot.reviewQuestionIds.length),'待复习错题');
        this.Metric(String(snapshot.slowQuestionIds.length),'做对但偏慢');
      }
      .width('100%');

      Row({space:10}) {
        Button('高频词 '+this.selectedDayVocabularyCount+' 个',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(this.selectedDayVocabularyCount>0?AppTheme.PRIMARY:AppTheme.TERTIARY_TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.selectedDayVocabularyCount>0)
          .onClick(()=>this.openVocabulary());
        Button('阅读提速 '+this.selectedDaySentenceCount+' 句',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(this.selectedDaySentenceCount>0?AppTheme.PRIMARY:AppTheme.TERTIARY_TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.selectedDaySentenceCount>0)
          .onClick(()=>this.openSentenceDrills());
      }
      .width('100%');

      Text('训练题会先插入错题和慢题，再进入今天的主题内容，避免机械重复。')
        .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);

      Button(selectedDay===1?(snapshot.diagnosticCompleted?'重新进行 Day 1 快速诊断':'进入 Day 1 快速诊断'):'进入 Day '+selectedDay+' 训练',{type:ButtonType.Normal})
        .width('100%').height(AppTheme.BUTTON_HEIGHT)
        .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
        .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
        .onClick(()=>this.startTraining());
    }
    .width('100%').padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({width:1,color:AppTheme.BORDER})
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private DayButton(day:number,currentDay:number) {
    Button('Day '+day,{type:ButtonType.Normal})
      .layoutWeight(1)
      .height(40)
      .fontSize(AppTheme.META_SIZE)
      .fontWeight(day===this.selectedStudyDay?FontWeight.Bold:FontWeight.Regular)
      .fontColor(day===this.selectedStudyDay?AppTheme.TEXT_ON_PRIMARY:
        (day===currentDay?AppTheme.PRIMARY:AppTheme.TEXT))
      .backgroundColor(day===this.selectedStudyDay?AppTheme.PRIMARY:
        (day===currentDay?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE_SUBTLE))
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .onClick(()=>this.selectStudyDay(day));
  }

  @Builder
  private DaySelector(currentDay:number) {
    Column({space:10}) {
      Row() {
        Text('选择训练日')
          .fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Blank();
        Text('当前进度 Day '+currentDay)
          .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(1,currentDay);
        this.DayButton(2,currentDay);
        this.DayButton(3,currentDay);
        this.DayButton(4,currentDay);
      }
      .width('100%');

      Row({space:8}) {
        this.DayButton(5,currentDay);
        this.DayButton(6,currentDay);
        this.DayButton(7,currentDay);
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


  @Builder
  private HomeContent(snapshot:ToeicLearningSnapshot,selectedDay:number) {
    Scroll() {
      Column({space:AppTheme.SECTION_GAP_STANDARD}) {
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

        if (this.viewModel.contentErrors().length>0) {
          Text('内容校验未通过，正式训练内容已暂停。')
            .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.DANGER)
            .padding(AppTheme.CARD_PADDING_COMPACT).backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
        } else {
          this.DaySelector(snapshot.currentDay);
          this.TodayCard(snapshot,selectedDay);
          if (!snapshot.diagnosticCompleted && selectedDay!==1) {
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
              this.Metric(String(snapshot.totalAnswered),'累计答题');
              this.Metric(String(snapshot.totalCorrect),'累计正确');
              this.Metric(this.viewModel.accuracyValue(snapshot),'正确率');
            }
            .width('100%');
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
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),top:20,bottom:24});
    }
    .width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private VocabularyContent(items:ToeicVocabularyItem[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        DeepPageHeader({
          title:'Day '+this.selectedStudyDay+' 高频词',
          subtitle:this.selectedDayTitle+' · '+items.length+' 个',
          onBack:()=>this.cancelSession()
        });

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
                .height(34)
                .fontSize(AppTheme.META_SIZE)
                .fontColor(AppTheme.PRIMARY)
                .backgroundColor(AppTheme.PRIMARY_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(()=>{ void this.pronounce(item); });
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Text(item.meaning)
              .width('100%').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.TEXT);
            Text('场景：'+item.scenario)
              .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
            if (item.collocations.length>0) {
              Text('搭配：'+item.collocations.join(' · '))
                .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.PRIMARY);
            }
            if (item.paraphrases.length>0) {
              Text('同义：'+item.paraphrases.join(' · '))
                .width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
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
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_BOTTOM_PADDING});
    }
    .width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private SentenceContent(items:ToeicSentenceDrill[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        DeepPageHeader({
          title:'Day '+this.selectedStudyDay+' 阅读提速',
          subtitle:this.selectedDayTitle+' · '+items.length+' 句',
          onBack:()=>this.cancelSession()
        });
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
            Text('主干：'+item.core)
              .width('100%').fontSize(AppTheme.BODY_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
            Text('重点：'+item.focus)
              .width('100%').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
            Text(item.explanation)
              .width('100%').fontSize(AppTheme.BODY_SIZE)
              .lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
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
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_BOTTOM_PADDING});
    }
    .width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  @Builder
  private QuestionContent() {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        DeepPageHeader({
          title:this.mode===ToeicPageMode.DIAGNOSTIC?'Reading 快速诊断':'今日训练',
          subtitle:String(this.currentIndex+1)+' / '+this.questions.length+' · '+
            this.viewModel.partLabel(this.currentPart),
          trailingText:'建议 '+this.currentRecommendedSeconds+'s',
          onBack:()=>this.cancelSession()
        });

        Column({space:12}) {
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

          if (this.currentPassage.length>0) {
            Text(this.currentPassage)
              .width('100%').fontSize(AppTheme.READING_BODY_SIZE).lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
              .fontColor(AppTheme.TEXT).padding(AppTheme.CARD_PADDING)
              .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
          }

          Text(this.currentStem)
            .width('100%').fontSize(AppTheme.QUESTION_TEXT_SIZE).lineHeight(AppTheme.QUESTION_TEXT_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);

          Column({space:9}) {
            Button('A. '+this.currentOptionA,{type:ButtonType.Normal})
              .width('100%').constraintSize({minHeight:50})
              .fontSize(AppTheme.FORM_TEXT_SIZE).fontColor(this.optionText(0))
              .backgroundColor(this.optionBackground(0))
              .border({width:1,color:this.optionBorder(0)})
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.chooseAnswer(0));

            Button('B. '+this.currentOptionB,{type:ButtonType.Normal})
              .width('100%').constraintSize({minHeight:50})
              .fontSize(AppTheme.FORM_TEXT_SIZE).fontColor(this.optionText(1))
              .backgroundColor(this.optionBackground(1))
              .border({width:1,color:this.optionBorder(1)})
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.chooseAnswer(1));

            Button('C. '+this.currentOptionC,{type:ButtonType.Normal})
              .width('100%').constraintSize({minHeight:50})
              .fontSize(AppTheme.FORM_TEXT_SIZE).fontColor(this.optionText(2))
              .backgroundColor(this.optionBackground(2))
              .border({width:1,color:this.optionBorder(2)})
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.chooseAnswer(2));

            if (this.currentOptionCount>3) {
              Button('D. '+this.currentOptionD,{type:ButtonType.Normal})
                .width('100%').constraintSize({minHeight:50})
                .fontSize(AppTheme.FORM_TEXT_SIZE).fontColor(this.optionText(3))
                .backgroundColor(this.optionBackground(3))
                .border({width:1,color:this.optionBorder(3)})
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(()=>this.chooseAnswer(3));
            }
          }
          .width('100%');

          if (this.answerLocked) {
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

            Button(this.currentIndex+1>=this.questions.length?'完成本轮':'下一题',{type:ButtonType.Normal})
              .width('100%').height(AppTheme.BUTTON_HEIGHT)
              .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
              .onClick(()=>this.nextQuestion());
          }
        }
        .width('100%').padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%').constraintSize({maxWidth:AppTheme.CONTENT_NARROW_MAX_WIDTH})
      .padding({left:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        right:LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
        top:AppTheme.DEEP_PAGE_TOP_PADDING,bottom:AppTheme.DEEP_PAGE_BOTTOM_PADDING});
    }
    .width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart);
  }

  build() {
    Column() {
      if (this.mode===ToeicPageMode.HOME) {
        this.HomeContent(
          this.viewModel.snapshot(),
          this.effectiveStudyDay()
        );
      } else if (this.mode===ToeicPageMode.VOCABULARY) {
        this.VocabularyContent(
          this.viewModel.vocabularyForDay(this.effectiveStudyDay())
        );
      } else if (this.mode===ToeicPageMode.SENTENCE) {
        this.SentenceContent(
          this.viewModel.sentenceDrillsForDay(this.effectiveStudyDay())
        );
      } else if (this.currentQuestionId.length>0) {
        this.QuestionContent();
      }
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center).backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue,newValue)=>{
      this.availableWidthVp=LayoutPolicy.areaLengthToVp(newValue.width,this.availableWidthVp);
    });
  }
}
