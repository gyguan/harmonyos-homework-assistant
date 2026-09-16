import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentFilterDialog } from './AssignmentFilterDialog';
import { StudentAssignmentsViewModel } from './StudentAssignmentsViewModel';

@Component
export struct StudentAssignmentsPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;

  @State private typeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private subjectCode: string = 'ALL';
  @State private dateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private draftTypeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private draftSubjectCode: string = 'ALL';
  @State private draftDateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private querying: boolean = false;

  @State private needHandlingAssignments: Assignment[] = [];
  @State private notStartedAssignments: Assignment[] = [];
  @State private submittedAssignments: Assignment[] = [];
  @State private completedAssignments: Assignment[] = [];
  @State private visibleTotal: number = 0;
  @State private totalCount: number = 0;

  onOpenDetail: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: StudentAssignmentsViewModel =
    new StudentAssignmentsViewModel(DefaultAssignmentRepository.instance);

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: AssignmentFilterDialog({
      typeFilter: $draftTypeFilter,
      dateFilter: $draftDateFilter,
      subjectCode: $draftSubjectCode,
      onQuery: (typeFilter: AssignmentTypeFilter, dateFilter: AssignmentDateFilter, subjectCode: string) => {
        void this.applyFilters(typeFilter, dateFilter, subjectCode);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

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
    if (currentRevision < 0) return;
    this.totalCount = this.viewModel.allCount();
    this.rebuildResults();
  }

  private rebuildResults(): void {
    this.applyItems(this.viewModel.assignments(this.typeFilter, this.subjectCode, this.dateFilter));
  }

  private applyItems(items: Assignment[]): void {
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

  private openFilterDialog(): void {
    if (this.querying) return;
    this.draftTypeFilter = this.typeFilter;
    this.draftSubjectCode = this.subjectCode;
    this.draftDateFilter = this.dateFilter;
    this.filterDialogController.open();
  }

  private async applyFilters(typeFilter: AssignmentTypeFilter,
    dateFilter: AssignmentDateFilter, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.querying = true;

    this.draftTypeFilter = typeFilter;
    this.draftDateFilter = dateFilter;
    this.draftSubjectCode = subjectCode;
    this.typeFilter = typeFilter;
    this.dateFilter = dateFilter;
    this.subjectCode = subjectCode;
    this.filterDialogController.close();

    try {
      let items = await this.viewModel.query(typeFilter, subjectCode, dateFilter);
      this.applyItems(items);
    } finally {
      this.querying = false;
    }
  }

  private hasActiveFilters(): boolean {
    return this.typeFilter !== AssignmentTypeFilter.ALL || this.subjectCode !== 'ALL' ||
      this.dateFilter !== AssignmentDateFilter.ALL;
  }

  private typeLabel(value: AssignmentTypeFilter): string {
    if (value === AssignmentTypeFilter.SCHOOL) return '课内';
    if (value === AssignmentTypeFilter.EXTRA) return '课外';
    return '全部';
  }

  private dateLabel(value: AssignmentDateFilter): string {
    if (value === AssignmentDateFilter.TODAY) return '今天';
    if (value === AssignmentDateFilter.TOMORROW) return '明天';
    if (value === AssignmentDateFilter.THIS_WEEK) return '本周';
    if (value === AssignmentDateFilter.UNDATED) return '未定';
    return '全部日期';
  }

  private subjectLabel(value: string): string {
    if (value === 'CHINESE') return '语文';
    if (value === 'MATH') return '数学';
    if (value === 'ENGLISH') return '英语';
    if (value === 'OTHER') return '其他';
    return '全部科目';
  }

  @Builder
  private FilterEntry(label: string, value: string, active: boolean) {
    Column({ space: 3 }) {
      Text(label).fontSize(11).fontColor(AppTheme.TERTIARY_TEXT);
      Row({ space: 3 }) {
        Text(value)
          .fontSize(13)
          .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(active ? AppTheme.PRIMARY : AppTheme.TEXT);
        Text('⌄').fontSize(11).fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      }
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${label}：${value}，打开筛选`)
    .onClick(() => this.openFilterDialog());
  }

  @Builder
  private FilterBar() {
    Row() {
      this.FilterEntry('类型', this.typeLabel(this.typeFilter), this.typeFilter !== AssignmentTypeFilter.ALL);
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      this.FilterEntry('截止', this.dateLabel(this.dateFilter), this.dateFilter !== AssignmentDateFilter.ALL);
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      this.FilterEntry('科目', this.subjectLabel(this.subjectCode), this.subjectCode !== 'ALL');
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      Text(this.querying ? '查询中…' : (this.hasActiveFilters() ? '筛选中' : '筛选'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasActiveFilters() ? AppTheme.PRIMARY : AppTheme.TEXT)
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 14, right: 14 })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('打开筛选面板')
        .onClick(() => this.openFilterDialog());
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private SectionHeader(title: string, description: string, count: number) {
    Row() {
      Column({ space: 2 }) {
        Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(description).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      Text(`${count}`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%');
  }

  @Builder
  private NeedHandlingSection() {
    if (this.needHandlingAssignments.length > 0) {
      Column({ space: 9 }) {
        this.SectionHeader('需要处理', '进行中、待订正、逾期或待提交', this.needHandlingAssignments.length);
        Column({ space: 6 }) {
          ForEach(this.needHandlingAssignments, (item: Assignment) => {
            AssignmentListItem({ assignment: item, selected: false, onOpen: () => this.onOpenDetail(item.id) });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private NotStartedSection() {
    if (this.notStartedAssignments.length > 0) {
      Column({ space: 9 }) {
        this.SectionHeader('待开始', '还没有开始的作业', this.notStartedAssignments.length);
        Column({ space: 6 }) {
          ForEach(this.notStartedAssignments, (item: Assignment) => {
            AssignmentListItem({ assignment: item, selected: false, onOpen: () => this.onOpenDetail(item.id) });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private SubmittedSection() {
    if (this.submittedAssignments.length > 0) {
      Column({ space: 9 }) {
        this.SectionHeader('已提交', '等待家长确认', this.submittedAssignments.length);
        Column({ space: 6 }) {
          ForEach(this.submittedAssignments, (item: Assignment) => {
            AssignmentListItem({ assignment: item, selected: false, onOpen: () => this.onOpenDetail(item.id) });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private CompletedSection() {
    if (this.completedAssignments.length > 0) {
      Column({ space: 9 }) {
        this.SectionHeader('已完成', '已经完成并验收', this.completedAssignments.length);
        Column({ space: 6 }) {
          ForEach(this.completedAssignments, (item: Assignment) => {
            AssignmentListItem({ assignment: item, selected: false, onOpen: () => this.onOpenDetail(item.id) });
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
        SymbolGlyph($r('sys.symbol.checkmark_square')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
        Text(this.totalCount === 0 ? '暂时没有作业' : '当前筛选下没有作业')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('打开筛选面板调整条件后重新查询。').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ top: 30, bottom: 30 });
    }
  }

  @Builder
  private AssignmentSections() {
    Column({ space: 22 }) {
      Row() {
        Text(this.hasActiveFilters() ? '筛选结果' : '全部作业')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.visibleTotal} 项`).fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      this.NeedHandlingSection();
      this.NotStartedSection();
      this.SubmittedSection();
      this.CompletedSection();
      this.EmptyState();
    }
    .width('100%');
  }

  @Builder
  private AssignmentListPage() {
    Column() {
      Scroll() {
        Column() {
          Column({ space: 18 }) {
            Column({ space: 4 }) {
              Text('我的作业').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Text('通过筛选快速找到要完成的任务。').fontSize(13).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            this.FilterBar();
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
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center);
  }

  build() {
    this.AssignmentListPage();
  }
}
