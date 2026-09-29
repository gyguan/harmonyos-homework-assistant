import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import {
  PracticeDifficulty,
  PracticeSubject,
  PracticeTrack
} from '../../../domain/model/practice/PracticeModels';
import { ParentPracticeGenerationViewModel } from './ParentPracticeGenerationViewModel';

@Component
export struct ParentPracticeGenerationPage {
  @State private subject: PracticeSubject = PracticeSubject.MATH;
  @State private track: PracticeTrack = PracticeTrack.TEXTBOOK_SYNC;
  @State private difficulty: PracticeDifficulty = PracticeDifficulty.L1;
  @State private questionCount: number = 12;
  @State private requirement: string = '';
  @State private message: string = '';

  onBack: () => void = () => {};
  onGenerate: (
    subject: PracticeSubject,
    track: PracticeTrack,
    difficulty: PracticeDifficulty,
    questionCount: number,
    requirement: string
  ) => void = (
    _subject: PracticeSubject,
    _track: PracticeTrack,
    _difficulty: PracticeDifficulty,
    _questionCount: number,
    _requirement: string
  ) => {};

  private readonly viewModel: ParentPracticeGenerationViewModel =
    new ParentPracticeGenerationViewModel();

  private startGenerate(): void {
    let normalized = this.requirement.trim();
    if (normalized.length === 0) {
      this.message = '请先填写希望孩子重点练习的内容';
      return;
    }
    this.message = '';
    this.onGenerate(
      this.subject,
      this.track,
      this.difficulty,
      this.questionCount,
      normalized);
  }

  private selectSubject(value: PracticeSubject): void {
    this.subject = value;
    this.message = '';
  }

  private selectTrack(value: PracticeTrack): void {
    this.track = value;
    this.message = '';
  }

  private selectDifficulty(value: PracticeDifficulty): void {
    this.difficulty = value;
    this.message = '';
  }

  private selectQuestionCount(value: number): void {
    this.questionCount = value;
    this.message = '';
  }

  @Builder
  private ContextCard() {
    Column({ space: 6 }) {
      Row() {
        Text('出题对象')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(this.viewModel.student().name)
          .fontSize(AppTheme.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%');

      Text(`${this.viewModel.student().grade} · ${this.viewModel.student().semester}`)
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .fontColor(AppTheme.SUBTEXT);

      if (this.viewModel.student().textbookSummary.length > 0) {
        Text('教材：' + this.viewModel.student().textbookSummary)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      } else if (this.track === PracticeTrack.TEXTBOOK_SYNC) {
        Text('教材同步出题需要先在孩子资料中配置教材信息')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private GenerationForm() {
    Column({ space: 15 }) {
      Text('科目')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '语文',
          selected: this.subject === PracticeSubject.CHINESE,
          onSelect: () => this.selectSubject(PracticeSubject.CHINESE)
        });
        SegmentedSelectionButton({
          label: '数学',
          selected: this.subject === PracticeSubject.MATH,
          onSelect: () => this.selectSubject(PracticeSubject.MATH)
        });
        SegmentedSelectionButton({
          label: '英语',
          selected: this.subject === PracticeSubject.ENGLISH,
          onSelect: () => this.selectSubject(PracticeSubject.ENGLISH)
        });
      }
      .width('100%');

      Text('题库类型')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '教材同步',
          selected: this.track === PracticeTrack.TEXTBOOK_SYNC,
          onSelect: () => this.selectTrack(PracticeTrack.TEXTBOOK_SYNC)
        });
        SegmentedSelectionButton({
          label: '课外拓展',
          selected: this.track === PracticeTrack.EXTRACURRICULAR,
          onSelect: () => this.selectTrack(PracticeTrack.EXTRACURRICULAR)
        });
      }
      .width('100%');

      Text('难度')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '基础',
          selected: this.difficulty === PracticeDifficulty.L1,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L1)
        });
        SegmentedSelectionButton({
          label: '提升',
          selected: this.difficulty === PracticeDifficulty.L2,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L2)
        });
        SegmentedSelectionButton({
          label: '挑战',
          selected: this.difficulty === PracticeDifficulty.L3,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L3)
        });
      }
      .width('100%');

      Text('题量')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 6 }) {
        SegmentedSelectionButton({
          label: '5题',
          selected: this.questionCount === 5,
          onSelect: () => this.selectQuestionCount(5)
        });
        SegmentedSelectionButton({
          label: '10题',
          selected: this.questionCount === 10,
          onSelect: () => this.selectQuestionCount(10)
        });
        SegmentedSelectionButton({
          label: '12题',
          selected: this.questionCount === 12,
          onSelect: () => this.selectQuestionCount(12)
        });
        SegmentedSelectionButton({
          label: '15题',
          selected: this.questionCount === 15,
          onSelect: () => this.selectQuestionCount(15)
        });
      }
      .width('100%');

      Column({ space: 6 }) {
        Text('我希望重点练习')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        TextArea({
          placeholder: '例如：100以内退位减法，多一些生活应用题，重点区分加法和减法',
          text: this.requirement
        })
          .width('100%')
          .height(118)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => {
            this.requirement = value.length <= 500 ? value : value.substring(0, 500);
            this.message = '';
          });
        Text(`${this.requirement.length}/500`)
          .width('100%')
          .textAlign(TextAlign.End)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_STANDARD)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_STANDARD);
  }

  @Builder
  private BottomActionBar() {
    Column() {
      Button('AI生成练习', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.startGenerate());
    }
    .width('100%')
    .padding({ top: 10, bottom: 14 });
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: 'AI生成练习',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: 12 }) {
            this.ContextCard();

            Text('设置训练目标后进入生成页面。AI会完成出题与质量校验，确认题目后再发布给孩子。')
              .width('100%')
              .fontSize(AppTheme.CAPTION_SIZE)
              .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT)
              .padding(12)
              .backgroundColor(AppTheme.PRIMARY_FAINT)
              .borderRadius(AppTheme.CONTROL_RADIUS);

            this.GenerationForm();

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(AppTheme.META_SIZE)
                .lineHeight(AppTheme.META_LINE_HEIGHT)
                .fontColor(AppTheme.DANGER)
                .padding(12)
                .backgroundColor(AppTheme.DANGER_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }
          }
          .width('100%')
          .padding({ bottom: 8 });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);

        this.BottomActionBar();
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
