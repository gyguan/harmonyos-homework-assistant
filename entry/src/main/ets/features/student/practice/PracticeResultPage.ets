import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  PracticeAttemptMode,
  PracticeQuestionResult,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { PracticeResultViewModel } from './PracticeResultViewModel';

@Component
export struct PracticeResultPage {
  @Prop attemptId: string = '';
  @State private result: PracticeResult | null = null;
  @State private paperTitle: string = '';
  @State private errorMessage: string = '';
  @State private repeating: boolean = false;
  @State private wrongRetrying: boolean = false;
  @State private showDetailedStats: boolean = false;
  @State private showAllQuestions: boolean = false;
  onBack: () => void = () => {};
  onRepeatStarted: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticeResultViewModel = new PracticeResultViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.errorMessage = '';
    this.paperTitle = '';
    try {
      let loaded = await this.viewModel.load(this.attemptId);
      this.result = loaded;
      this.paperTitle = await this.viewModel.paperTitle(loaded);
    } catch {
      this.result = null;
      this.errorMessage = '结果加载失败，请检查网络后重试。';
    }
  }

  private headerSubtitle(): string {
    if (this.result === null) return this.paperTitle;
    if (this.paperTitle.length > 0) return `${this.paperTitle} · 第 ${this.result.attemptNo} 次`;
    return `第 ${this.result.attemptNo} 次`;
  }

  private async repeat(): Promise<void> {
    if (this.repeating || this.wrongRetrying || this.result === null) return;
    this.repeating = true;
    this.errorMessage = '';
    try {
      let repeated = await this.viewModel.repeat(this.attemptId);
      this.onRepeatStarted(repeated.id);
    } catch {
      this.errorMessage = '再次练习创建失败，请检查网络后重试。';
    } finally {
      this.repeating = false;
    }
  }

  private async retryWrong(): Promise<void> {
    if (this.repeating || this.wrongRetrying || this.result === null || this.result.wrongCount <= 0) return;
    this.wrongRetrying = true;
    this.errorMessage = '';
    try {
      let repeated = await this.viewModel.retryWrong(this.attemptId);
      this.onRepeatStarted(repeated.id);
    } catch {
      this.errorMessage = '错题专项创建失败，请检查网络后重试。';
    } finally {
      this.wrongRetrying = false;
    }
  }

  @Builder
  private Metric(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(label).fontSize(12).fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      Column() {
        DeepPageHeader({
          title: '练习结果',
          subtitle: this.headerSubtitle(),
          backAccessibilityText: '返回上一页',
          onBack: () => this.onBack()
        });
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 16 }) {
          if (this.result !== null) {
            Column({ space: 6 }) {
              if (this.result.mode === PracticeAttemptMode.WRONG_ONLY) {
                Text('错题专项')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.PRIMARY)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .backgroundColor(AppTheme.PRIMARY_SOFT)
                  .borderRadius(AppTheme.CHIP_RADIUS);
              }
              Text(`${this.result.score} / ${this.result.maxScore}`)
                .fontSize(42)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.PRIMARY);
              Text(`正确率 ${this.viewModel.percent(this.result)}%`)
                .fontSize(14)
                .fontColor(AppTheme.SUBTEXT);
              if (this.result.noteCount > 0) {
                Text(`本次记录 ${this.result.noteCount} 条笔记`)
                  .fontSize(13)
                  .fontColor(AppTheme.TERTIARY_TEXT);
              }
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);

            Column({ space: 8 }) {
              Text(this.showDetailedStats ? '收起详细统计' : '查看详细统计')
                .width('100%')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.PRIMARY)
                .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText(this.showDetailedStats ? '收起详细统计' : '查看详细统计')
                .onClick(() => this.showDetailedStats = !this.showDetailedStats);
              if (this.showDetailedStats) {
                Row({ space: 10 }) {
                  this.Metric(`${this.result.correctCount}`, '答对');
                  this.Metric(`${this.result.wrongCount}`, '答错/未答');
                  this.Metric(this.viewModel.elapsedText(this.result.elapsedSeconds), '用时');
                }
                .width('100%');
              }
            }
            .width('100%');

            Column({ space: 10 }) {
              Row() {
                Text(this.result.wrongCount > 0 && !this.showAllQuestions ? '错题优先 · 答题回顾' : '答题回顾')
                  .layoutWeight(1)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                if (this.result.wrongCount > 0) {
                  Text(this.showAllQuestions ? '只看错题' : '查看全部题目')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.PRIMARY)
                    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
                    .accessibilityRole(AccessibilityRoleType.BUTTON)
                    .accessibilityText(this.showAllQuestions ? '只查看错题' : '查看全部题目')
                    .onClick(() => this.showAllQuestions = !this.showAllQuestions);
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);

              ForEach(this.result.questions, (item: PracticeQuestionResult) => {
                if (this.showAllQuestions || this.result!.wrongCount === 0 || !item.correct) {
                  Column({ space: 6 }) {
                  Row() {
                    Text(`第 ${item.orderNo} 题`)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.TEXT);
                    Blank();
                    Text(item.correct ? '正确' : '需订正')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(item.correct ? AppTheme.SUCCESS : AppTheme.DANGER);
                  }
                  .width('100%');
                  Text(item.stem)
                    .width('100%')
                    .fontSize(14)
                    .lineHeight(20)
                    .fontColor(AppTheme.TEXT);
                  Text(`我的答案：${item.answerValue.length > 0 ? item.answerValue : '未作答'}`)
                    .width('100%')
                    .fontSize(13)
                    .fontColor(AppTheme.SUBTEXT);
                  if (!item.correct) {
                    Text(`正确答案：${item.correctAnswer}`)
                      .width('100%')
                      .fontSize(13)
                      .fontColor(AppTheme.SUCCESS);
                  }
                  Text(item.explanation)
                    .width('100%')
                    .fontSize(13)
                    .lineHeight(18)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                  if (item.noteContent.length > 0) {
                    Column({ space: 4 }) {
                      Text('我的笔记')
                        .width('100%')
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.SUBTEXT);
                      Text(item.noteContent)
                        .width('100%')
                        .fontSize(13)
                        .lineHeight(18)
                        .fontColor(AppTheme.TEXT);
                    }
                    .width('100%')
                    .padding(10)
                    .backgroundColor(AppTheme.SURFACE_SUBTLE)
                    .borderRadius(AppTheme.CONTROL_RADIUS);
                  }
                }
                .width('100%')
                .padding(14)
                  .backgroundColor(AppTheme.SURFACE)
                  .borderRadius(AppTheme.CONTROL_RADIUS);
                }
              }, (item: PracticeQuestionResult) => item.questionId);
            }
            .width('100%');
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding({
          left: AppTheme.PAGE_PADDING,
          right: AppTheme.PAGE_PADDING,
          top: AppTheme.DEEP_PAGE_CONTENT_GAP,
          bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING
        });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off);

      if (this.result !== null) {
        Row({ space: 10 }) {
          Button(this.repeating ? '正在创建…' : '再练一遍', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.BUTTON_HEIGHT)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .fontWeight(FontWeight.Medium)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.repeating && !this.wrongRetrying)
            .onClick(() => void this.repeat());

          if (this.result.wrongCount > 0) {
            Button(this.wrongRetrying ? '正在创建…' : '只练错题', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(AppTheme.BUTTON_HEIGHT)
              .backgroundColor(this.wrongRetrying ? AppTheme.DISABLED : AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .fontWeight(FontWeight.Medium)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.repeating && !this.wrongRetrying)
              .onClick(() => void this.retryWrong());
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 10, bottom: 14 });
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
