import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, TextAction } from '../../../components/action/ActionControls';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePaper,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { PracticePaperDetailViewModel } from './PracticePaperDetailViewModel';

@Component
export struct PracticePaperDetailPage {
  @Prop paperId: string = '';
  @Prop version: number = 1;
  @State private paper: PracticePaper | null = null;
  @State private attempts: PracticeAttemptSummary[] = [];
  @State private recentAttempts: PracticeAttemptSummary[] = [];
  @State private loading: boolean = true;
  @State private historyLoading: boolean = true;
  @State private starting: boolean = false;
  @State private errorMessage: string = '';
  @State private historyErrorMessage: string = '';
  onBack: () => void = () => {};
  onStarted: (attemptId: string) => void = (_attemptId: string) => {};
  onOpenAttempt: (attemptId: string) => void = (_attemptId: string) => {};
  onOpenResult: (attemptId: string) => void = (_attemptId: string) => {};
  onOpenHistory: (paperId: string) => void = (_paperId: string) => {};
  private readonly viewModel: PracticePaperDetailViewModel = new PracticePaperDetailViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.historyLoading = true;
    this.errorMessage = '';
    this.historyErrorMessage = '';
    try {
      this.paper = await this.viewModel.getPaper(this.paperId, this.version);
      if (this.paper === null) {
        this.errorMessage = '套卷不存在或已下架。';
        this.attempts = [];
        this.recentAttempts = [];
        return;
      }
      try {
        this.attempts = await this.viewModel.listAttempts(this.paperId);
        this.recentAttempts = this.viewModel.recentAttempts(this.attempts);
      } catch {
        this.attempts = [];
        this.recentAttempts = [];
        this.historyErrorMessage = '练习记录暂时无法加载。';
      }
    } catch {
      this.paper = null;
      this.attempts = [];
      this.recentAttempts = [];
      this.errorMessage = '套卷加载失败，请稍后重试。';
    } finally {
      this.loading = false;
      this.historyLoading = false;
    }
  }

  private async start(): Promise<void> {
    if (this.paper === null || this.starting) return;
    this.starting = true;
    this.errorMessage = '';
    try {
      let attempt = await this.viewModel.start(this.paper.id, this.paper.version);
      this.onStarted(attempt.id);
    } catch {
      this.errorMessage = '开始练习失败，请检查网络和家庭云端连接。';
    } finally {
      this.starting = false;
    }
  }

  private openAttempt(item: PracticeAttemptSummary): void {
    if (item.status === PracticeAttemptStatus.SUBMITTED) this.onOpenResult(item.id);
    else this.onOpenAttempt(item.id);
  }

  @Builder
  private RecentAttemptCard(item: PracticeAttemptSummary) {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        Text(`第 ${item.attemptNo} 次 · ${this.viewModel.modeLabel(item)}`)
          .layoutWeight(1)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.viewModel.recordStatusLabel(item))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status !== PracticeAttemptStatus.SUBMITTED || this.viewModel.isWrongOnly(item) ?
            AppTheme.PRIMARY : (this.viewModel.isPassed(item) ? AppTheme.SUCCESS : AppTheme.WARNING))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(item.status !== PracticeAttemptStatus.SUBMITTED || this.viewModel.isWrongOnly(item) ?
            AppTheme.PRIMARY_SOFT : (this.viewModel.isPassed(item) ? AppTheme.SUCCESS_SOFT : AppTheme.WARNING_SOFT))
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%');

      Row({ space: 7 }) {
        Text(this.viewModel.scoreText(item))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        if (item.status === PracticeAttemptStatus.SUBMITTED) {
          Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
          Text(this.viewModel.correctRateText(item))
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

      Row({ space: 7 }) {
        Text(this.viewModel.timeText(item.startedAtEpochMs))
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
        if (item.status === PracticeAttemptStatus.SUBMITTED) {
          Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`完成耗时 ${this.viewModel.elapsedText(item.elapsedSeconds)}`)
            .fontSize(12)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
      }
      .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`第${item.attemptNo}次练习，${this.viewModel.recordStatusLabel(item)}${item.status === PracticeAttemptStatus.SUBMITTED ? `，完成耗时${this.viewModel.elapsedText(item.elapsedSeconds)}` : ''}`)
    .onClick(() => this.openAttempt(item));
  }

  @Builder
  private HistorySection() {
    Column({ space: 10 }) {
      Row() {
        Text('我的练习记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.attempts.length > 0) {
          TextAction({
            label: '查看全部',
            accessibilityLabel: '查看当前套卷全部练习记录',
            onClick: () => this.onOpenHistory(this.paperId)
          });
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.historyLoading) {
        Text('正在加载练习记录…')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .padding({ top: 12, bottom: 12 })
          .textAlign(TextAlign.Center);
      } else if (this.historyErrorMessage.length > 0) {
        Text(this.historyErrorMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .padding(12)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (this.recentAttempts.length === 0) {
        Text('还没有练习记录')
          .width('100%')
          .fontSize(13)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT)
          .padding(12)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Column({ space: 6 }) {
          Text('最近一次')
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.TERTIARY_TEXT);
          this.RecentAttemptCard(this.recentAttempts[0]);
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  build() {
    Column() {
      Column() {
        DeepPageHeader({
          title: '套卷详情',
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
        Column({ space: 16 }) {
          if (this.paper !== null) {
            Column({ space: 8 }) {
              Text(this.paper.title)
                .width('100%')
                .fontSize(AppTheme.PAGE_TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT);
              Text(`${PracticeTaxonomy.gradeLabel(this.paper.grade)} · ${PracticeTaxonomy.semesterLabel(this.paper.semester)} · ${PracticeTaxonomy.subjectLabel(this.paper.subject)} · ${PracticeTaxonomy.difficultyLabel(this.paper.difficulty)}`)
                .width('100%')
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              Text(this.paper.description)
                .width('100%')
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            Text(`${this.paper.questionCount} 题 · 约 ${this.paper.estimatedMinutes} 分钟 · ${PracticeTaxonomy.difficultyLabel(this.paper.difficulty)}`)
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);

            if (this.paper.tags.length > 0) {
              Text(this.paper.tags.join(' · '))
                .width('100%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontSize(13)
                .lineHeight(18)
                .fontColor(AppTheme.TERTIARY_TEXT);
            }

            this.HistorySection();
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          } else if (this.loading) {
            Text('正在加载套卷…')
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.SUBTEXT)
              .padding({ top: 24, bottom: 24 })
              .textAlign(TextAlign.Center);
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

      if (this.paper !== null) {
        Column() {
          ActionButton({
            label: this.starting ? '正在开始…' : '开始练习',
            isEnabled: !this.starting,
            onClick: () => void this.start()
          })
          .width('100%');
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
