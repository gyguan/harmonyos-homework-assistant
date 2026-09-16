import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { StudentAssignmentsViewModel } from './StudentAssignmentsViewModel';

@Component
export struct StudentAssignmentsPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private typeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private subjectCode: string = 'ALL';
  @State private dateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;

  @State private needHandlingAssignments: Assignment[] = [];
  @State private notStartedAssignments: Assignment[] = [];
  @State private submittedAssignments: Assignment[] = [];
  @State private completedAssignments: Assignment[] = [];
  @State private visibleTotal: number = 0;

  @State private totalCount: number = 0;
  @State private schoolCount: number = 0;
  @State private extraCount: number = 0;
  @State private todayCount: number = 0;
  @State private tomorrowCount: number = 0;
  @State private weekCount: number = 0;
  @State private chineseCount: number = 0;
  @State private mathCount: number = 0;
  @State private englishCount: number = 0;
  @State private otherCount: number = 0;

  onOpenDetail: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: StudentAssignmentsViewModel =
    new StudentAssignmentsViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    this.rebuildView();
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    await this.viewModel.refresh();
    this.refreshRevision++;
    this.rebuildView();
  }

  private rebuildView(): void {
    let currentRevision = this.revision + this.refreshRevision;
    this.rebuildCounts();
    this.rebuildResults();
  }

  private rebuildCounts(): void {
    this.totalCount = this.viewModel.allCount();
    this.schoolCount = this.viewModel.typeCount(AssignmentTypeFilter.SCHOOL);
    this.extraCount = this.viewModel.typeCount(AssignmentTypeFilter.EXTRA);
    this.todayCount = this.viewModel.dateCount(AssignmentDateFilter.TODAY);
    this.tomorrowCount = this.viewModel.dateCount(AssignmentDateFilter.TOMORROW);
    this.weekCount = this.viewModel.dateCount(AssignmentDateFilter.THIS_WEEK);
    this.chineseCount = this.viewModel.subjectCount('CHINESE');
    this.mathCount = this.viewModel.subjectCount('MATH');
    this.englishCount = this.viewModel.subjectCount('ENGLISH');
    this.otherCount = this.viewModel.subjectCount('OTHER');
  }

  private rebuildResults(): void {
    let items = this.viewModel.assignments(this.typeFilter, this.subjectCode, this.dateFilter);
    let needHandling: Assignment[] = [];
    let notStarted: Assignment[] = [];
    let submitted: Assignment[] = [];
    let completed: Assignment[] = [];

    for (let item of items) {
      if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED ||
        item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.OVERDUE ||
        item.status === AssignmentStatus.READY_TO_SUBMIT) {
        needHandling.push(item);
      } else if (item.status === AssignmentStatus.NOT_STARTED) {
        notStarted.push(item);
      } else if (item.status === AssignmentStatus.SUBMITTED) {
        submitted.push(item);
      } else if (item.status === AssignmentStatus.COMPLETED) {
        completed.push(item);
      }
    }

    this.visibleTotal = items.length;
    this.needHandlingAssignments = needHandling;
    this.notStartedAssignments = notStarted;
    this.submittedAssignments = submitted;
    this.completedAssignments = completed;
  }

  private selectType(key: AssignmentTypeFilter): void {
    if (this.typeFilter === key) return;
    this.typeFilter = key;
    this.rebuildResults();
  }

  private selectDate(key: AssignmentDateFilter): void {
    if (this.dateFilter === key) return;
    this.dateFilter = key;
    this.rebuildResults();
  }

  private selectSubject(key: string): void {
    if (this.subjectCode === key) return;
    this.subjectCode = key;
    this.rebuildResults();
  }

  private resetFilters(): void {
    this.typeFilter = AssignmentTypeFilter.ALL;
    this.subjectCode = 'ALL';
    this.dateFilter = AssignmentDateFilter.ALL;
    this.rebuildResults();
  }

  private hasActiveFilters(): boolean {
    return this.typeFilter !== AssignmentTypeFilter.ALL || this.subjectCode !== 'ALL' ||
      this.dateFilter !== AssignmentDateFilter.ALL;
  }

  private typeCount(typeFilter: AssignmentTypeFilter): number {
    if (typeFilter === AssignmentTypeFilter.SCHOOL) return this.schoolCount;
    if (typeFilter === AssignmentTypeFilter.EXTRA) return this.extraCount;
    return this.totalCount;
  }

  private subjectCount(subjectCode: string): number {
    if (subjectCode === 'CHINESE') return this.chineseCount;
    if (subjectCode === 'MATH') return this.mathCount;
    if (subjectCode === 'ENGLISH') return this.englishCount;
    if (subjectCode === 'OTHER') return this.otherCount;
    return this.totalCount;
  }

  private dateCount(dateFilter: AssignmentDateFilter): number {
    if (dateFilter === AssignmentDateFilter.TODAY) return this.todayCount;
    if (dateFilter === AssignmentDateFilter.TOMORROW) return this.tomorrowCount;
    if (dateFilter === AssignmentDateFilter.THIS_WEEK) return this.weekCount;
    return this.totalCount;
  }

  @Builder
  private TypeChip(key: AssignmentTypeFilter, label: string) {
    Text(`${label} ${this.typeCount(key)}`)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .fontSize(13)
      .fontWeight(this.typeFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.typeFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor(this.typeFilter === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.typeFilter === key ? `${label}，已选择，${this.typeCount(key)}项` : `${label}，${this.typeCount(key)}项`)
      .onClick(() => this.selectType(key));
  }

  @Builder
  private SubjectChip(key: string, label: string) {
    Text(`${label} ${this.subjectCount(key)}`)
      .fontSize(13)
      .fontWeight(this.subjectCode === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.subjectCode === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(this.subjectCode === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.subjectCode === key ? `${label}，已选择，${this.subjectCount(key)}项` : `${label}，${this.subjectCount(key)}项`)
      .onClick(() => this.selectSubject(key));
  }

  @Builder
  private DateChip(key: AssignmentDateFilter, label: string) {
    Text(`${label} ${this.dateCount(key)}`)
      .fontSize(13)
      .fontWeight(this.dateFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.dateFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(this.dateFilter === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.dateFilter === key ? `${label}，已选择，${this.dateCount(key)}项` : `${label}，${this.dateCount(key)}项`)
      .onClick(() => this.selectDate(key));
  }

  @Builder
  private FilterPanel() {
    Column({ space: 14 }) {
      Row() {
        Text('筛选作业')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.hasActiveFilters()) {
          Text('重置')
            .fontSize(13)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 10, right: 4, top: 8, bottom: 8 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('重置筛选')
            .onClick(() => this.resetFilters());
        }
      }
      .width('100%');

      Column({ space: 8 }) {
        Text('类型').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
        Row({ space: 8 }) {
          this.TypeChip(AssignmentTypeFilter.ALL, '全部');
          this.TypeChip(AssignmentTypeFilter.SCHOOL, '课内');
          this.TypeChip(AssignmentTypeFilter.EXTRA, '课外');
        }
        .width('100%');
      }
      .width('100%');

      Divider().color(AppTheme.DIVIDER);

      Column({ space: 8 }) {
        Text('截止').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
        Scroll() {
          Row({ space: 6 }) {
            this.DateChip(AssignmentDateFilter.ALL, '全部日期');
            this.DateChip(AssignmentDateFilter.TODAY, '今天');
            this.DateChip(AssignmentDateFilter.TOMORROW, '明天');
            this.DateChip(AssignmentDateFilter.THIS_WEEK, '本周');
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      .width('100%');

      Divider().color(AppTheme.DIVIDER);

      Column({ space: 8 }) {
        Text('科目').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
        Scroll() {
          Row({ space: 6 }) {
            this.SubjectChip('ALL', '全部科目');
            this.SubjectChip('CHINESE', '语文');
            this.SubjectChip('MATH', '数学');
            this.SubjectChip('ENGLISH', '英语');
            this.SubjectChip('OTHER', '其他');
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      .width('100%');
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private Section(title: string, description: string, items: Assignment[]) {
    if (items.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text(description).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${items.length}`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');

        Column({ space: 6 }) {
          ForEach(items, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: false,
              onOpen: () => this.onOpenDetail(item.id)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private EmptyState() {
    if (this.visibleTotal === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square'))
          .fontSize(30)
          .fontColor([AppTheme.TERTIARY_TEXT]);
        Text(this.totalCount === 0 ? '暂时没有作业' : '当前筛选下没有作业')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('换一个类型、日期或科目看看。').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ top: 30, bottom: 30 });
    }
  }

  @Builder
  private AssignmentSections() {
    Column({ space: 22 }) {
      Row() {
        Text('筛选结果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.visibleTotal} 项`)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      this.Section('需要处理', '进行中、待订正、逾期或待提交', this.needHandlingAssignments);
      this.Section('待开始', '还没有开始的作业', this.notStartedAssignments);
      this.Section('已提交', '等待家长确认', this.submittedAssignments);
      this.Section('已完成', '已经完成并验收', this.completedAssignments);
      this.EmptyState();
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 18 }) {
          Column({ space: 4 }) {
            Text('我的作业').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            Text('先筛选，再从结果中选择要完成的任务。').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          this.FilterPanel();
          this.AssignmentSections();
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }
}
