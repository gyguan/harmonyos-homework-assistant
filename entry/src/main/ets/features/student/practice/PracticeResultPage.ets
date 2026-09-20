import { AppTheme } from '../../../common/theme/AppTheme';
import { PracticeQuestionResult, PracticeResult } from '../../../domain/model/practice/PracticeModels';
import { PracticeResultViewModel } from './PracticeResultViewModel';

@Component
export struct PracticeResultPage {
  @Prop attemptId: string = '';
  @State private result: PracticeResult | null = null;
  @State private errorMessage: string = '';
  onDone: () => void = () => {};
  private readonly viewModel: PracticeResultViewModel = new PracticeResultViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.errorMessage = '';
    try {
      this.result = await this.viewModel.load(this.attemptId);
    } catch {
      this.errorMessage = '结果加载失败，请检查网络后重试。';
    }
  }

  @Builder
  private Metric(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(label).fontSize(11).fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('练习结果')
          .fontSize(AppTheme.DEEP_PAGE_HEADER_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('完成')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .onClick(() => this.onDone());
      }
      .width('100%')
      .height(AppTheme.DEEP_PAGE_HEADER_HEIGHT)
      .padding({ left: 20, right: 16 });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 16 }) {
          if (this.result !== null) {
            Column({ space: 6 }) {
              Text(`${this.result.score} / ${this.result.maxScore}`)
                .fontSize(42)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.PRIMARY);
              Text(`正确率 ${this.viewModel.percent(this.result)}%`)
                .fontSize(14)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);

            Row({ space: 10 }) {
              this.Metric(`${this.result.correctCount}`, '答对');
              this.Metric(`${this.result.wrongCount}`, '答错/未答');
              this.Metric(this.viewModel.elapsedText(this.result.elapsedSeconds), '用时');
            }
            .width('100%');

            Column({ space: 10 }) {
              Text('答题回顾')
                .width('100%')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              ForEach(this.result.questions, (item: PracticeQuestionResult) => {
                Column({ space: 6 }) {
                  Row() {
                    Text(`第 ${item.orderNo} 题`)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.TEXT);
                    Blank();
                    Text(item.correct ? '正确' : '需订正')
                      .fontSize(12)
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
                    .fontSize(12)
                    .fontColor(AppTheme.SUBTEXT);
                  if (!item.correct) {
                    Text(`正确答案：${item.correctAnswer}`)
                      .width('100%')
                      .fontSize(12)
                      .fontColor(AppTheme.SUCCESS);
                  }
                  Text(item.explanation)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
                .width('100%')
                .padding(14)
                .backgroundColor(AppTheme.SURFACE)
                .borderRadius(AppTheme.CONTROL_RADIUS);
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
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      if (this.result !== null) {
        Row() {
          Button('返回练习', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(() => this.onDone());
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 14 })
        .backgroundColor(AppTheme.SURFACE);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
