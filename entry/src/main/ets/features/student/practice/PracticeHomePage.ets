import { AppTheme } from '../../../common/theme/AppTheme';
import { PracticeFilterDialog } from '../../../components/practice/PracticeFilterDialog';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import {
  PracticeGrade,
  PracticePaper,
  PracticePassFilter,
  PracticeSemester,
  PracticeSubject,
  PracticeTrackFilter
} from '../../../domain/model/practice/PracticeModels';
import { PracticeHomeViewModel } from './PracticeHomeViewModel';

@Component
struct PracticePaperCard {
  @Prop paper: PracticePaper;
  @Prop difficultyLabel: string = '';
  @Prop passed: boolean = false;
  onOpen: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.paper.title)
          .layoutWeight(1)
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        if (this.passed) {
          Text('已通过')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUCCESS)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(AppTheme.SUCCESS_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(`${this.paper.questionCount} 题 · 约 ${this.paper.estimatedMinutes} 分钟 · ${this.difficultyLabel}`)
        .width('100%')
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);

      if (this.paper.description.length > 0) {
        Text(this.paper.description)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(13)
          .lineHeight(18)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${this.paper.title}，${this.paper.questionCount}题，${this.passed ? '已通过，' : ''}点击查看套卷`)
    .onClick(() => this.onOpen());
  }
}

@Component
export struct PracticeHomePage {
  @Prop revision: number = 0;
  onOpenPaper: (paperId: string, version: number) => void = (_paperId: string, _version: number) => {};
  onOpenHistory: () => void = () => {};
  @State private selectedGrade: PracticeGrade = PracticeGrade.G3;
  @State private selectedSubject: PracticeSubject = PracticeSubject.MATH;
  @State private selectedSemester: PracticeSemester = PracticeSemester.ALL;
  @State private selectedTrack: PracticeTrackFilter = PracticeTrackFilter.TEXTBOOK_SYNC;
  @State private selectedPassFilter: PracticePassFilter = PracticePassFilter.ALL;
  @State private draftSelectedGrade: PracticeGrade = PracticeGrade.G3;
  @State private draftSelectedSubject: PracticeSubject = PracticeSubject.MATH;
  @State private draftSelectedTrack: PracticeTrackFilter = PracticeTrackFilter.TEXTBOOK_SYNC;
  @State private draftSelectedPassFilter: PracticePassFilter = PracticePassFilter.ALL;
  @State private allPapers: PracticePaper[] = [];
  @State private papers: PracticePaper[] = [];
  @State private passedPaperIds: string[] = [];
  @State private passStatusAvailable: boolean = false;
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  private loadSequence: number = 0;
  private readonly viewModel: PracticeHomeViewModel = new PracticeHomeViewModel();

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: PracticeFilterDialog({
      selectedGrade: $draftSelectedGrade,
      selectedSubject: $draftSelectedSubject,
      selectedTrack: $draftSelectedTrack,
      selectedPassFilter: $draftSelectedPassFilter,
      onApply: (grade: PracticeGrade, subject: PracticeSubject, track: PracticeTrackFilter,
        passFilter: PracticePassFilter) => {
        this.applyFilters(grade, subject, track, passFilter);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  aboutToAppear(): void {
    this.selectedGrade = this.viewModel.defaultGrade();
    this.selectedSemester = this.viewModel.defaultSemester();
    this.draftSelectedGrade = this.selectedGrade;
    this.draftSelectedSubject = this.selectedSubject;
    this.draftSelectedTrack = this.selectedTrack;
    this.draftSelectedPassFilter = this.selectedPassFilter;
    void this.reloadPapers();
  }

  private async reloadPapers(): Promise<void> {
    let sequence = ++this.loadSequence;
    this.loading = true;
    this.errorMessage = '';
    try {
      let papers = await this.viewModel.listPapers(
        this.selectedGrade, this.selectedSubject, this.selectedSemester, this.selectedTrack);
      let passedIds: string[] = [];
      let statusAvailable = true;
      try {
        let attempts = await this.viewModel.listAttempts();
        passedIds = this.viewModel.passedPaperIds(attempts);
      } catch {
        statusAvailable = false;
      }
      if (sequence !== this.loadSequence) return;
      this.allPapers = papers;
      this.passedPaperIds = passedIds;
      this.passStatusAvailable = statusAvailable;
      this.refreshPaperPresentation();
    } catch {
      if (sequence !== this.loadSequence) return;
      this.allPapers = [];
      this.papers = [];
      this.passedPaperIds = [];
      this.passStatusAvailable = false;
      this.errorMessage = '套卷加载失败，请稍后重试。';
    } finally {
      if (sequence === this.loadSequence) this.loading = false;
    }
  }

  private refreshPaperPresentation(): void {
    if (this.selectedPassFilter === PracticePassFilter.ALL) {
      this.papers = this.allPapers.slice();
      return;
    }
    if (!this.passStatusAvailable) {
      this.papers = [];
      this.errorMessage = '练习通过状态加载失败，请连接家庭云端后重试。';
      return;
    }
    this.errorMessage = '';
    this.papers = this.viewModel.filterByPass(
      this.allPapers, this.selectedPassFilter, this.passedPaperIds);
  }

  private openFilterDialog(): void {
    if (this.loading) return;
    this.draftSelectedGrade = this.selectedGrade;
    this.draftSelectedSubject = this.selectedSubject;
    this.draftSelectedTrack = this.selectedTrack;
    this.draftSelectedPassFilter = this.selectedPassFilter;
    this.filterDialogController.open();
  }

  private applyFilters(
    grade: PracticeGrade,
    subject: PracticeSubject,
    track: PracticeTrackFilter,
    passFilter: PracticePassFilter
  ): void {
    let catalogChanged = grade !== this.selectedGrade || subject !== this.selectedSubject ||
      track !== this.selectedTrack;
    let passChanged = passFilter !== this.selectedPassFilter;
    this.selectedGrade = grade;
    this.selectedSubject = subject;
    this.selectedTrack = track;
    this.selectedPassFilter = passFilter;
    this.filterDialogController.close();
    if (catalogChanged || (passChanged && !this.passStatusAvailable &&
      passFilter !== PracticePassFilter.ALL)) {
      void this.reloadPapers();
      return;
    }
    if (passChanged) this.refreshPaperPresentation();
  }

  @Builder
  private FilterBar() {
    Row() {
      FilterSummaryEntry({
        label: '年级',
        value: this.viewModel.gradeLabel(this.selectedGrade),
        active: true,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '科目',
        value: this.viewModel.subjectLabel(this.selectedSubject),
        active: true,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '题库类型',
        value: this.viewModel.trackFilterLabel(this.selectedTrack),
        active: true,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '通过状态',
        value: this.viewModel.passFilterLabel(this.selectedPassFilter),
        active: this.selectedPassFilter !== PracticePassFilter.ALL,
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
  private PaperList() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('练习套卷')
          .layoutWeight(1)
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.loading ? '加载中…' : `${this.papers.length} 套`)
          .constraintSize({ minWidth: 64 })
          .maxLines(1)
          .textAlign(TextAlign.End)
          .fontSize(14)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.DANGER)
          .padding(14)
          .backgroundColor(AppTheme.DANGER_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (!this.loading && this.papers.length === 0) {
        Column({ space: 7 }) {
          Text('这个分类暂时没有套卷')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .padding({ top: 28, bottom: 28 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      } else {
        Column({ space: 9 }) {
          ForEach(this.papers, (paper: PracticePaper) => {
            PracticePaperCard({
              paper: paper,
              difficultyLabel: this.viewModel.difficultyLabel(paper),
              passed: this.viewModel.isPaperPassed(paper, this.passedPaperIds),
              onOpen: () => this.onOpenPaper(paper.id, paper.version)
            });
          }, (paper: PracticePaper) => `${paper.id}@${paper.version}`);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 18 }) {
          Column({ space: 5 }) {
            Row() {
              Text('练习')
                .fontSize(AppTheme.PAGE_TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT);
              Blank();
              Text('练习记录')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.PRIMARY)
                .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
                .padding({ left: 12, right: 2 })
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText('查看练习记录')
                .onClick(() => this.onOpenHistory());
            }
            .width('100%');
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          this.FilterBar();

          this.PaperList();

        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
