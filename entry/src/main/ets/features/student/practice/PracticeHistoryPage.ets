import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { PracticeHistoryFilterDialog } from '../../../components/practice/PracticeHistoryFilterDialog';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import {
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePassFilter,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import {
  PracticeHistorySubjectFilter,
  PracticeHistoryTimeFilter
} from '../../../domain/model/PracticeHistoryFilter';
import {
  PracticeHistoryStatistics,
  PracticeHistoryViewModel
} from './PracticeHistoryViewModel';

@Component
export struct PracticeHistoryPage {
  @Prop paperId: string = '';
  @State private allAttempts: PracticeAttemptSummary[] = [];
  @State private attempts: PracticeAttemptSummary[] = [];
  @State private statistics: PracticeHistoryStatistics = new PracticeHistoryStatistics();
  @State private selectedSubject: PracticeHistorySubjectFilter = PracticeHistorySubjectFilter.ALL;
  @State private selectedTime: PracticeHistoryTimeFilter = PracticeHistoryTimeFilter.ALL;
  @State private selectedPass: PracticePassFilter = PracticePassFilter.ALL;
  @State private draftSelectedSubject: PracticeHistorySubjectFilter = PracticeHistorySubjectFilter.ALL;
  @State private draftSelectedTime: PracticeHistoryTimeFilter = PracticeHistoryTimeFilter.ALL;
  @State private draftSelectedPass: PracticePassFilter = PracticePassFilter.ALL;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  onBack: () => void = () => {};
  onOpenAttempt: (attemptId: string) => void = (_attemptId: string) => {};
  onOpenResult: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticeHistoryViewModel = new PracticeHistoryViewModel();

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: PracticeHistoryFilterDialog({
      selectedSubject: $draftSelectedSubject,
      selectedTime: $draftSelectedTime,
      selectedPass: $draftSelectedPass,
      showSubject: true,
      onApply: (
        subject: PracticeHistorySubjectFilter,
        time: PracticeHistoryTimeFilter,
        pass: PracticePassFilter
      ) => {
        this.applyFilters(subject, time, pass);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private paperFilterDialogController: CustomDialogController = new CustomDialogController({
    builder: PracticeHistoryFilterDialog({
      selectedSubject: $draftSelectedSubject,
      selectedTime: $draftSelectedTime,
      selectedPass: $draftSelectedPass,
      showSubject: false,
      onApply: (
        subject: PracticeHistorySubjectFilter,
        time: PracticeHistoryTimeFilter,
        pass: PracticePassFilter
      ) => {
        this.applyFilters(subject, time, pass);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

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
    this.attempts = this.viewModel.filter(
      this.allAttempts,
      this.isPaperScoped() ? PracticeHistorySubjectFilter.ALL : this.selectedSubject,
      this.selectedTime,
      this.selectedPass,
      Date.now()
    );
    this.statistics = this.viewModel.statistics(this.attempts);
  }

  private isPaperScoped(): boolean {
    return this.paperId.length > 0;
  }

  private openFilterDialog(): void {
    this.draftSelectedSubject =
      this.isPaperScoped() ? PracticeHistorySubjectFilter.ALL : this.selectedSubject;
    this.draftSelectedTime = this.selectedTime;
    this.draftSelectedPass = this.selectedPass;
    if (this.isPaperScoped()) this.paperFilterDialogController.open();
    else this.filterDialogController.open();
  }

  private applyFilters(
    subject: PracticeHistorySubjectFilter,
    time: PracticeHistoryTimeFilter,
    pass: PracticePassFilter
  ): void {
    this.selectedSubject = this.isPaperScoped() ? PracticeHistorySubjectFilter.ALL : subject;
    this.selectedTime = time;
    this.selectedPass = pass;
    if (this.isPaperScoped()) this.paperFilterDialogController.close();
    else this.filterDialogController.close();
    this.refreshPresentation();
  }

  private open(item: PracticeAttemptSummary): void {
    if (item.status === PracticeAttemptStatus.SUBMITTED) this.onOpenResult(item.id);
    else this.onOpenAttempt(item.id);
  }

  private statusFontColor(item: PracticeAttemptSummary): string {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return AppTheme.PRIMARY;
    if (this.viewModel.isWrongOnly(item)) return AppTheme.PRIMARY;
    return this.viewModel.isPassed(item) ? AppTheme.SUCCESS : AppTheme.WARNING;
  }

  private statusBackgroundColor(item: PracticeAttemptSummary): string {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return AppTheme.PRIMARY_SOFT;
    if (this.viewModel.isWrongOnly(item)) return AppTheme.PRIMARY_SOFT;
    return this.viewModel.isPassed(item) ? AppTheme.SUCCESS_SOFT : AppTheme.WARNING_SOFT;
  }

  @Builder
  private FilterBar() {
    Row() {
      if (!this.isPaperScoped()) {
        FilterSummaryEntry({
          label: '科目',
          value: this.viewModel.subjectFilterLabel(this.selectedSubject),
          active: this.selectedSubject !== PracticeHistorySubjectFilter.ALL,
          onOpen: () => this.openFilterDialog()
        });
        Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      }

      FilterSummaryEntry({
        label: '时间',
        value: this.viewModel.timeFilterLabel(this.selectedTime),
        active: this.selectedTime !== PracticeHistoryTimeFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '通过状态',
        value: this.viewModel.passFilterLabel(this.selectedPass),
        active: this.selectedPass !== PracticePassFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private Metric(value: string, label: string, tone: string) {
    Column({ space: 5 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(tone === 'success' ? AppTheme.SUCCESS : AppTheme.PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 76 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(tone === 'success' ? AppTheme.SUCCESS_SOFT :
      tone === 'neutral' ? AppTheme.SURFACE_EMPHASIS : AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private StatisticsCard() {
    Column({ space: 8 }) {
      Row() {
        Text('练习统计')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('基于当前筛选 · 仅统计已完成')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Row({ space: 8 }) {
        this.Metric(`${this.statistics.completedCount}`, '完成次数', 'primary');
        this.Metric(this.viewModel.correctRateText(this.statistics), '正确率', 'success');
        this.Metric(this.viewModel.averageElapsedText(this.statistics), '平均耗时', 'neutral');
      }
      .width('100%');
    }
    .width('100%');
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
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(this.viewModel.recordStatusLabel(item))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusFontColor(item))
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.statusBackgroundColor(item))
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Row({ space: 8 }) {
        Text(this.viewModel.scoreText(item))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
        Text(this.viewModel.timeText(item.startedAtEpochMs))
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
        if (item.status === PracticeAttemptStatus.SUBMITTED) {
          Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`完成耗时 ${this.viewModel.elapsedText(item.elapsedSeconds)}`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        if (item.noteCount > 0) {
          Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${item.noteCount} 条笔记`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        Blank();
        Text('查看')
          .fontSize(13)
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
    .accessibilityText(
      `${item.paperTitle}第${item.attemptNo}次练习，${this.viewModel.recordStatusLabel(item)}${item.status === PracticeAttemptStatus.SUBMITTED ?
        `，完成耗时${this.viewModel.elapsedText(item.elapsedSeconds)}` : ''}`
    )
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
          this.FilterBar();

          if (!this.loading && this.errorMessage.length === 0) {
            this.StatisticsCard();
          }

          Text('每次开始练习都会创建独立实例，历史记录不会被后续重练覆盖。')
            .width('100%')
            .fontSize(13)
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
                .fontSize(13)
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
              Text(this.isPaperScoped() ? '可以调整时间或通过状态继续查看。' : '可以调整科目、时间或通过状态继续查看。')
                .fontSize(13)
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
