import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import {
  PracticeHistoryStatistics,
  PracticeHistoryStatusFilter,
  PracticeHistorySubjectFilter,
  PracticeHistoryViewModel
} from './PracticeHistoryViewModel';

@Component
export struct PracticeHistoryPage {
  @Prop paperId: string = '';
  @State private allAttempts: PracticeAttemptSummary[] = [];
  @State private attempts: PracticeAttemptSummary[] = [];
  @State private statistics: PracticeHistoryStatistics = new PracticeHistoryStatistics();
  @State private selectedStatus: PracticeHistoryStatusFilter = PracticeHistoryStatusFilter.ALL;
  @State private selectedSubject: PracticeHistorySubjectFilter = PracticeHistorySubjectFilter.ALL;
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
      this.allAttempts = await this.viewModel.list(this.paperId);
      this.refreshPresentation();
    } catch {
      this.allAttempts = [];
      this.attempts = [];
      this.statistics = new PracticeHistoryStatistics();
      this.errorMessage = '练习记录加载失败，请检查网络后重试。';
    } finally {
      this.loading = false;
    }
  }

  private refreshPresentation(): void {
    this.attempts = this.viewModel.filter(this.allAttempts, this.selectedStatus, this.selectedSubject);
    this.statistics = this.viewModel.statistics(this.allAttempts, this.selectedSubject);
  }

  private isPaperScoped(): boolean {
    return this.paperId.length > 0;
  }

  private selectStatus(status: PracticeHistoryStatusFilter): void {
    if (status === this.selectedStatus) return;
    this.selectedStatus = status;
    this.refreshPresentation();
  }

  private selectSubject(subject: PracticeHistorySubjectFilter): void {
    if (subject === this.selectedSubject) return;
    this.selectedSubject = subject;
    this.refreshPresentation();
  }

  private open(item: PracticeAttemptSummary): void {
    if (item.status === PracticeAttemptStatus.SUBMITTED) this.onOpenResult(item.id);
    else this.onOpenAttempt(item.id);
  }

  @Builder
  private StatusOption(status: PracticeHistoryStatusFilter) {
    Button(this.viewModel.statusFilterLabel(status), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(this.selectedStatus === status ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedStatus === status ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedStatus === status ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectStatus(status));
  }

  @Builder
  private SubjectOption(subject: PracticeHistorySubjectFilter) {
    Button(this.viewModel.subjectFilterLabel(subject), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(this.selectedSubject === subject ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedSubject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedSubject === subject ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectSubject(subject));
  }

  @Builder
  private FilterSection() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text('状态')
          .width(34)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        this.StatusOption(PracticeHistoryStatusFilter.ALL);
        this.StatusOption(PracticeHistoryStatusFilter.SUBMITTED);
        this.StatusOption(PracticeHistoryStatusFilter.IN_PROGRESS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (!this.isPaperScoped()) {
        Row({ space: 6 }) {
          Text('科目')
            .width(34)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
          this.SubjectOption(PracticeHistorySubjectFilter.ALL);
          this.SubjectOption(PracticeHistorySubjectFilter.CHINESE);
          this.SubjectOption(PracticeHistorySubjectFilter.MATH);
          this.SubjectOption(PracticeHistorySubjectFilter.ENGLISH);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private Metric(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private StatisticsCard() {
    Column({ space: 8 }) {
      Row() {
        Text('练习统计')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('仅统计已完成')
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Row({ space: 7 }) {
        this.Metric(`${this.statistics.completedCount}次`, '完成');
        this.Metric(this.viewModel.correctRateText(this.statistics), '正确率');
        this.Metric(this.viewModel.averageElapsedText(this.statistics), '平均耗时');
      }
      .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
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
          Text(`${PracticeTaxonomy.gradeLabel(item.grade)} · ${PracticeTaxonomy.subjectLabel(item.subject)} · ${this.viewModel.modeLabel(item)} · 第 ${item.attemptNo} 次`)
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
          Text(`耗时 ${this.viewModel.elapsedText(item.elapsedSeconds)}`)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        if (item.noteCount > 0) {
          Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${item.noteCount} 条笔记`)
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
      Column() {
        DeepPageHeader({
          title: '练习记录',
          subtitle: this.isPaperScoped() ? '当前套卷' : '',
          backAccessibilityText: '返回练习',
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
        Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
          this.FilterSection();

          if (!this.loading && this.errorMessage.length === 0 &&
            this.viewModel.showStatistics(this.selectedStatus)) {
            this.StatisticsCard();
          }

          Text('每次开始练习都会创建独立实例，历史记录不会被后续重练覆盖。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.TERTIARY_TEXT);

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          } else if (this.loading) {
            Text('正在加载练习记录…')
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.SUBTEXT)
              .padding({ top: 24, bottom: 24 })
              .textAlign(TextAlign.Center);
          } else if (this.allAttempts.length === 0) {
            Column({ space: 7 }) {
              Text(this.isPaperScoped() ? '这套卷还没有练习记录' : '还没有练习记录')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text(this.isPaperScoped() ? '完成这套练习后，每一次结果都会保留在这里。' : '完成第一套练习后，每一次结果都会保留在这里。')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .padding({ top: 32, bottom: 32 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);
          } else if (this.attempts.length === 0) {
            Column({ space: 7 }) {
              Text('没有符合条件的练习记录')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text('可以切换状态或科目继续查看。')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .padding({ top: 28, bottom: 28 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);
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
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
