import { LayoutPolicy } from '../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../common/theme/AppTheme';
import { DeepPageHeader } from '../../components/navigation/DeepPageHeader';
import { ToeicLearningSnapshot, ToeicPerformance, ToeicQuestion, ToeicQuestionAttempt, ToeicScoreValue, ToeicSentenceDrill, ToeicStudyDay, ToeicVocabularyItem } from '../domain/ToeicModels';
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
  private readonly viewModel:ToeicCoachViewModel=new ToeicCoachViewModel();
  private attempts:ToeicQuestionAttempt[]=[];

  aboutToAppear():void { this.refreshRevision++; }

  private currentQuestion():ToeicQuestion|null {
    if (this.currentIndex<0 || this.currentIndex>=this.questions.length) return null;
    return this.questions[this.currentIndex];
  }

  private startDiagnostic():void { this.startSession(ToeicPageMode.DIAGNOSTIC,this.viewModel.diagnosticQuestions()); }
  private startTraining():void { this.startSession(ToeicPageMode.TRAINING,this.viewModel.dailyQuestions()); }
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
    this.mode=mode; this.questions=questions; this.currentIndex=0; this.selectedIndex=-1;
    this.answerLocked=false; this.answerCorrect=false; this.questionStartedAtMs=Date.now(); this.attempts=[];
  }

  private cancelSession():void {
    this.mode=ToeicPageMode.HOME; this.questions=[]; this.attempts=[]; this.answerLocked=false; this.selectedIndex=-1;
  }

  private chooseAnswer(index:number):void {
    if (this.answerLocked) return;
    let question=this.currentQuestion();
    if (question===null) return;
    let elapsed=Math.max(1,Math.round((Date.now()-this.questionStartedAtMs)/1000));
    let attempt=this.viewModel.createAttempt(question,index,elapsed);
    this.attempts.push(attempt); this.selectedIndex=index; this.answerCorrect=attempt.correct; this.answerLocked=true;
  }

  private nextQuestion():void {
    if (!this.answerLocked) return;
    if (this.currentIndex+1>=this.questions.length) { void this.finishSession(); return; }
    this.currentIndex++; this.selectedIndex=-1; this.answerLocked=false; this.answerCorrect=false; this.questionStartedAtMs=Date.now();
  }

  private async finishSession():Promise<void> {
    await this.viewModel.completeSession(this.attempts,this.mode===ToeicPageMode.DIAGNOSTIC);
    this.refreshRevision++; this.mode=ToeicPageMode.HOME; this.questions=[]; this.attempts=[];
    this.answerLocked=false; this.selectedIndex=-1;
  }

  private optionBackground(index:number,question:ToeicQuestion):string {
    if (!this.answerLocked) return AppTheme.SURFACE;
    if (index===question.correctIndex) return AppTheme.SUCCESS_SOFT;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER_SOFT;
    return AppTheme.SURFACE;
  }

  private optionBorder(index:number,question:ToeicQuestion):string {
    if (!this.answerLocked) return AppTheme.BORDER;
    if (index===question.correctIndex) return AppTheme.SUCCESS;
    if (index===this.selectedIndex && !this.answerCorrect) return AppTheme.DANGER;
    return AppTheme.BORDER;
  }

  private optionText(index:number,question:ToeicQuestion):string {
    if (!this.answerLocked) return AppTheme.TEXT;
    if (index===question.correctIndex) return AppTheme.SUCCESS;
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
  private IntroCard() {
    Column({space:14}) {
      Text('先做一次快速诊断')
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text('先找出真正影响 Reading 350+ 的薄弱点，再安排高价值训练。')
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      Row({space:8}) {
        Text('12题').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        Text('·').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        Text('约10分钟').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        Text('·').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
        Text('记录正确率+速度').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      Button('开始诊断',{type:ButtonType.Normal})
        .width('100%').height(AppTheme.BUTTON_HEIGHT)
        .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.TEXT_ON_PRIMARY)
        .backgroundColor(AppTheme.PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
        .onClick(()=>this.startDiagnostic());
    }
    .width('100%').padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({width:1,color:AppTheme.BORDER})
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private TodayCard(snapshot:ToeicLearningSnapshot,plan:ToeicStudyDay) {
    Column({space:14}) {
      Row() {
        Column({space:4}) {
          Text('Day '+plan.day+' / 21')
            .fontSize(AppTheme.META_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          Text(plan.title)
            .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(plan.focus)
            .fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start);
        Text('约 '+plan.estimatedMinutes+' min').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%').alignItems(VerticalAlign.Top);

      Row({space:10}) {
        this.Metric(this.viewModel.skillLabel(snapshot.weakSkill),'当前薄弱点');
        this.Metric(String(snapshot.reviewQuestionIds.length),'待复习错题');
        this.Metric(String(snapshot.slowQuestionIds.length),'做对但偏慢');
      }
      .width('100%');

      Row({space:10}) {
        Button('高频词 '+plan.vocabularyIds.length+' 个',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.openVocabulary());
        Button('阅读提速 '+plan.sentenceDrillIds.length+' 句',{type:ButtonType.Normal})
          .layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
          .fontSize(AppTheme.ACTION_TEXT_SIZE).fontColor(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(()=>this.openSentenceDrills());
      }
      .width('100%');

      Text('训练题会先插入错题和慢题，再进入今天的主题内容，避免机械重复。')
        .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);

      Button('开始题型训练',{type:ButtonType.Normal})
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
  private WeekPlanCard(plans:ToeicStudyDay[],snapshot:ToeicLearningSnapshot) {
    Column({space:10}) {
      Text('第一周计划')
        .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      ForEach(plans,(plan:ToeicStudyDay)=>{
        Row({space:10}) {
          Text('Day '+plan.day)
            .fontSize(AppTheme.META_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(plan.day===snapshot.currentDay?AppTheme.PRIMARY:AppTheme.SUBTEXT)
            .constraintSize({minWidth:48});
          Column({space:2}) {
            Text(plan.title)
              .width('100%').fontSize(AppTheme.BODY_SIZE)
              .fontWeight(plan.day===snapshot.currentDay?FontWeight.Medium:FontWeight.Regular)
              .fontColor(AppTheme.TEXT);
            Text(plan.focus)
              .width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis});
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start);
          if (plan.day===1 && snapshot.diagnosticCompleted) {
            Text('已完成').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUCCESS);
          } else if (plan.day<snapshot.currentDay) {
            Text('已完成').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUCCESS);
          } else if (plan.day===snapshot.currentDay) {
            Text('今天').fontSize(AppTheme.META_SIZE).fontColor(AppTheme.PRIMARY);
          }
        }
        .width('100%')
        .padding({left:8,right:8,top:8,bottom:8})
        .backgroundColor(plan.day===snapshot.currentDay?AppTheme.PRIMARY_SOFT:AppTheme.CARD_SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      },(plan:ToeicStudyDay)=>String(plan.day));
    }
    .width('100%').padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE).borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private HomeContent(snapshot:ToeicLearningSnapshot,plan:ToeicStudyDay,plans:ToeicStudyDay[]) {
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
        } else if (!snapshot.diagnosticCompleted) {
          this.IntroCard();
        } else {
          this.TodayCard(snapshot,plan);
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

          this.WeekPlanCard(plans,snapshot);
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
  private VocabularyContent(plan:ToeicStudyDay,items:ToeicVocabularyItem[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        DeepPageHeader({
          title:'Day '+plan.day+' 高频词',
          subtitle:plan.title+' · '+items.length+' 个',
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
  private SentenceContent(plan:ToeicStudyDay,items:ToeicSentenceDrill[]) {
    Scroll() {
      Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
        DeepPageHeader({
          title:'Day '+plan.day+' 阅读提速',
          subtitle:plan.title+' · '+items.length+' 句',
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
  private QuestionContent(question:ToeicQuestion) {
    Scroll() {
        Column({space:AppTheme.DEEP_PAGE_CONTENT_GAP}) {
          DeepPageHeader({
            title:this.mode===ToeicPageMode.DIAGNOSTIC?'Reading 快速诊断':'今日训练',
            subtitle:String(this.currentIndex+1)+' / '+this.questions.length+' · '+this.viewModel.partLabel(question.part),
            trailingText:'建议 '+question.recommendedSeconds+'s',
            onBack:()=>this.cancelSession()
          });
          Column({space:12}) {
            Row() {
              Text(this.viewModel.skillLabel(question.skill))
                .fontSize(AppTheme.META_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
                .padding({left:9,right:9,top:5,bottom:5}).backgroundColor(AppTheme.PRIMARY_SOFT)
                .borderRadius(AppTheme.CHIP_RADIUS);
              Blank();
              Text(question.scoreValue===ToeicScoreValue.MUST_GET?'基础分优先':
                (question.scoreValue===ToeicScoreValue.OPTIONAL?'难题可取舍':'正常作答'))
                .fontSize(AppTheme.META_SIZE).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%');

            if (question.passage.length>0) {
              Text(question.passage)
                .width('100%').fontSize(AppTheme.READING_BODY_SIZE).lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
                .fontColor(AppTheme.TEXT).padding(AppTheme.CARD_PADDING)
                .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
            }

            Text(question.stem)
              .width('100%').fontSize(AppTheme.QUESTION_TEXT_SIZE).lineHeight(AppTheme.QUESTION_TEXT_LINE_HEIGHT)
              .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);

            Column({space:9}) {
              ForEach(question.options,(option:string,index:number)=>{
                Button(this.optionPrefix(index)+'. '+option,{type:ButtonType.Normal})
                  .width('100%').constraintSize({minHeight:50})
                  .fontSize(AppTheme.FORM_TEXT_SIZE).fontColor(this.optionText(index,question))
                  .backgroundColor(this.optionBackground(index,question))
                  .border({width:1,color:this.optionBorder(index,question)})
                  .borderRadius(AppTheme.CONTROL_RADIUS)
                  .onClick(()=>this.chooseAnswer(index));
              },(option:string)=>question.id+':'+option);
            }
            .width('100%');

            if (this.answerLocked) {
              Column({space:7}) {
                Text(this.answerCorrect?'✓ 判断正确':'× 这题需要再巩固')
                  .fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Bold)
                  .fontColor(this.answerCorrect?AppTheme.SUCCESS:AppTheme.DANGER);
                Text(question.explanation)
                  .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(AppTheme.BODY_LINE_HEIGHT).fontColor(AppTheme.TEXT);
                if (question.evidence.length>0) {
                  Text('证据：'+question.evidence)
                    .width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
                }
                if (question.paraphrase.length>0) {
                  Text('替换关系：'+question.paraphrase)
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
        this.HomeContent(this.viewModel.snapshot(),this.viewModel.todayPlan(),this.viewModel.weekOnePlans());
      } else if (this.mode===ToeicPageMode.VOCABULARY) {
        this.VocabularyContent(this.viewModel.todayPlan(),this.viewModel.todayVocabulary());
      } else if (this.mode===ToeicPageMode.SENTENCE) {
        this.SentenceContent(this.viewModel.todayPlan(),this.viewModel.todaySentenceDrills());
      } else if (this.currentIndex>=0 && this.currentIndex<this.questions.length) {
        this.QuestionContent(this.questions[this.currentIndex]);
      }
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center).backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue,newValue)=>{
      this.availableWidthVp=LayoutPolicy.areaLengthToVp(newValue.width,this.availableWidthVp);
    });
  }
}
