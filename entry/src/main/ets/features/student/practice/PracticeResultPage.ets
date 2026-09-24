import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, TextAction } from '../../../components/action/ActionControls';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  PracticeAttemptMode,
  PracticeQuestionResult,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { PracticeProgressSummary, PracticeResultViewModel } from './PracticeResultViewModel';

@Component
export struct PracticeResultPage {
  @Prop attemptId: string = '';
  @State private result: PracticeResult | null = null;
  @State private paperTitle: string = '';
  @State private progress: PracticeProgressSummary | null = null;
  @State private errorMessage: string = '';
  @State private repeating: boolean = false;
  @State private wrongRetrying: boolean = false;
  @State private showDetailedStats: boolean = false;
  @State private showAllQuestions: boolean = false;
  @State private feedbackVisible: boolean = false;
  onBack: () => void = () => {};
  onRepeatStarted: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticeResultViewModel = new PracticeResultViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.errorMessage = '';
    this.paperTitle = '';
    this.progress = null;
    this.feedbackVisible = false;
    try {
      let loaded = await this.viewModel.load(this.attemptId);
      this.result = loaded;
      this.paperTitle = await this.viewModel.paperTitle(loaded);
      this.progress = await this.viewModel.progress(loaded);
      this.feedbackVisible = true;
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

  private feedbackTitle(result: PracticeResult): string {
    if (result.mode === PracticeAttemptMode.WRONG_ONLY && result.wrongCount === 0) {
      return '这些错题被你攻克啦！';
    }
    if (result.wrongCount === 0) return '全对啦！太棒了！';
    if (this.hasPositiveProgress()) return '这次有进步！';

    let percent = this.viewModel.percent(result);
    if (percent >= 80) return '做得很不错！';
    if (percent >= 60) return '完成啦，继续加油！';
    return '坚持做完很了不起！';
  }

  private feedbackSubtitle(result: PracticeResult): string {
    if (result.mode === PracticeAttemptMode.WRONG_ONLY) {
      if (result.wrongCount === 0) return '上次不会的题，现在已经会啦';
      return '已经攻克了一部分，再把剩下的弄懂';
    }
    if (result.wrongCount === 0) return '这些知识你已经掌握得很不错啦';
    if (this.hasPositiveProgress()) return '你把更多题目真正弄懂了';

    let percent = this.viewModel.percent(result);
    if (percent >= 80) return '你已经掌握了大部分题目';
    if (percent >= 60) return '已经会了不少，我们把错题再弄懂';
    return '不着急，我们一道一道把不会的弄懂';
  }

  private hasPositiveProgress(): boolean {
    return this.progress !== null && (this.progress.correctDelta > 0 || this.progress.percentDelta > 0);
  }

  private progressText(): string {
    if (this.progress === null) return '';
    if (this.progress.correctDelta > 0 && this.progress.percentDelta > 0) {
      return `比上次多答对 ${this.progress.correctDelta} 题 · 正确率 +${this.progress.percentDelta}%`;
    }
    if (this.progress.correctDelta > 0) return `比上次多答对 ${this.progress.correctDelta} 题`;
    if (this.progress.percentDelta > 0) return `正确率比上次提高 ${this.progress.percentDelta}%`;
    return '';
  }

  private nextStepText(result: PracticeResult): string {
    if (result.wrongCount <= 0) return '这一轮已经完成，给自己一个大大的赞！';
    if (result.mode === PracticeAttemptMode.WRONG_ONLY) {
      return `还剩 ${result.wrongCount} 道题，再试一次就更熟练啦`;
    }
    return `再把 ${result.wrongCount} 道错题弄懂就更棒啦`;
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

  @Builder
  private CompletionFeedback(result: PracticeResult) {
    Column({ space: 8 }) {
      Text('★')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY);

      Text(this.feedbackTitle(result))
        .width('100%')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT)
        .textAlign(TextAlign.Center);

      Text(this.feedbackSubtitle(result))
        .width('100%')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);

      Text(`${result.score} / ${result.maxScore}`)
        .fontSize(42)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .margin({ top: 4 });

      Text(`答对 ${result.correctCount} 题 · 正确率 ${this.viewModel.percent(result)}%`)
        .fontSize(14)
        .fontColor(AppTheme.SUBTEXT);

      if (this.progressText().length > 0) {
        Text(this.progressText())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUCCESS)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppTheme.SUCCESS_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS)
          .margin({ top: 2 });
      }

      Column({ space: 4 }) {
        Text(`✓ 认真完成了 ${result.questions.length} 道题`)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.TEXT)
          .textAlign(TextAlign.Center);
        if (result.noteCount > 0) {
          Text(`✎ 还记录了 ${result.noteCount} 条笔记`)
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.TEXT)
            .textAlign(TextAlign.Center);
        }
      }
      .width('100%')
      .margin({ top: 4 });

      Text(this.nextStepText(result))
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(result.wrongCount > 0 ? AppTheme.PRIMARY : AppTheme.SUCCESS)
        .textAlign(TextAlign.Center)
        .margin({ top: 2 });
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 22, bottom: 20 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS)
    .opacity(this.feedbackVisible ? 1 : 0.2)
    .scale({
      x: this.feedbackVisible ? 1 : 0.96,
      y: this.feedbackVisible ? 1 : 0.96
    })
    .animation({ duration: 360 });
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
            this.CompletionFeedback(this.result);

            Column({ space: 8 }) {
              TextAction({
                label: this.showDetailedStats ? '收起详细统计' : '查看详细统计',
                accessibilityLabel: this.showDetailedStats ? '收起详细统计' : '查看详细统计',
                onAction: () => this.showDetailedStats = !this.showDetailedStats
              })
              .width('100%');
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
                  TextAction({
                    label: this.showAllQuestions ? '只看错题' : '查看全部题目',
                    accessibilityLabel: this.showAllQuestions ? '只查看错题' : '查看全部题目',
                    onAction: () => this.showAllQuestions = !this.showAllQuestions
                  });
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
          if (this.result.wrongCount > 0) {
            ActionButton({
              label: this.repeating ? '正在创建…' : '再练一遍',
              kind: ActionButtonKind.NEUTRAL,
              isEnabled: !this.repeating && !this.wrongRetrying,
              onAction: () => void this.repeat()
            })
            .layoutWeight(1);

            ActionButton({
              label: this.wrongRetrying ? '正在创建…' : `再挑战 ${this.result.wrongCount} 道错题`,
              isEnabled: !this.repeating && !this.wrongRetrying,
              onAction: () => void this.retryWrong()
            })
            .layoutWeight(1);
          } else {
            ActionButton({
              label: this.repeating ? '正在创建…' : '再挑战一次',
              kind: ActionButtonKind.NEUTRAL,
              isEnabled: !this.repeating,
              onAction: () => void this.repeat()
            })
            .layoutWeight(1);

            ActionButton({
              label: '完成',
              isEnabled: !this.repeating,
              onAction: () => this.onBack()
            })
            .layoutWeight(1);
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
