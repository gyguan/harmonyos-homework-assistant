import { AppTheme } from '../../../common/theme/AppTheme';
import {
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { PracticeHistoryViewModel } from './PracticeHistoryViewModel';

@Component
export struct PracticeHistoryPage {
  @State private attempts: PracticeAttemptSummary[] = [];
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  onBack: () => void = () => {};
  onOpenAttempt: (attemptId: string) => void = (_attemptId: string) => {};
  onOpenResult: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticeHistoryViewModel = new PracticeHistoryViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      this.attempts = await this.viewModel.list();
    } catch {
      this.attempts = [];
      this.errorMessage = '练习记录加载失败，请检查网络后重试。';
    } finally {
      this.loading = false;
    }
  }

  private open(item: PracticeAttemptSummary): void {
    if (item.status === PracticeAttemptStatus.SUBMITTED) this.onOpenResult(item.id);
    else this.onOpenAttempt(item.id);
  }

  @Builder
  private HistoryCard(item: PracticeAttemptSummary) {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(item.paperTitle)
            .width('100%')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(`${PracticeTaxonomy.gradeLabel(item.grade)} · ${PracticeTaxonomy.subjectLabel(item.subject)} · 第 ${item.attemptNo} 次`)
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(this.viewModel.statusLabel(item))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status === PracticeAttemptStatus.SUBMITTED ? AppTheme.SUCCESS : AppTheme.PRIMARY)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(item.status === PracticeAttemptStatus.SUBMITTED ? AppTheme.SUCCESS_SOFT : AppTheme.PRIMARY_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Row({ space: 8 }) {
        Text(this.viewModel.scoreText(item))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
        Text(this.viewModel.timeText(item.startedAtEpochMs))
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        if (item.status === PracticeAttemptStatus.SUBMITTED) {
          Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
          Text(this.viewModel.elapsedText(item.elapsedSeconds))
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        Blank();
        Text('查看')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${item.paperTitle}第${item.attemptNo}次练习，${this.viewModel.statusLabel(item)}`)
    .onClick(() => this.open(item));
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.TEXT)
          .width(AppTheme.MIN_TOUCH_TARGET)
          .height(AppTheme.MIN_TOUCH_TARGET)
          .textAlign(TextAlign.Center)
          .onClick(() => this.onBack());
        Text('练习记录')
          .fontSize(AppTheme.DEEP_PAGE_HEADER_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
      }
      .width('100%')
      .height(AppTheme.DEEP_PAGE_HEADER_HEIGHT)
      .padding({ left: 8, right: 16 });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 12 }) {
          Text('每次开始练习都会创建独立实例，历史记录不会被后续重练覆盖。')
            .width('100%')
            .fontSize(13)
            .lineHeight(19)
            .fontColor(AppTheme.SUBTEXT);

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          } else if (!this.loading && this.attempts.length === 0) {
            Column({ space: 7 }) {
              Text('还没有练习记录')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text('完成第一套练习后，每一次结果都会保留在这里。')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .padding({ top: 32, bottom: 32 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);
          } else {
            Column({ space: 9 }) {
              ForEach(this.attempts, (item: PracticeAttemptSummary) => {
                this.HistoryCard(item);
              }, (item: PracticeAttemptSummary) => item.id);
            }
            .width('100%');
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
