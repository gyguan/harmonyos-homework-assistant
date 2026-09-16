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

  // Applied query state. The result list only changes after the user confirms with 查询.
  @State private typeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private subjectCode: string = 'ALL';
  @State private dateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;

  // Draft state lives inside the half-modal filter sheet.
  @State private isFilterSheetVisible: boolean = false;
  @State private draftTypeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private draftSubjectCode: string = 'ALL';
  @State private draftDateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;

  @State private needHandlingAssignments: Assignment[] = [];
  @State private notStartedAssignments: Assignment[] = [];
  @State private submittedAssignments: Assignment[] = [];
  @State private completedAssignments: Assignment[] = [];
  @State private visibleTotal: number = 0;
  @State private totalCount: number = 0;

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
    if (currentRevision < 0) return;
    this.totalCount = this.viewModel.allCount();
    this.rebuildResults();
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

  private openFilterSheet(): void {
    this.draftTypeFilter = this.typeFilter;
    this.draftSubjectCode = this.subjectCode;
    this.draftDateFilter = this.dateFilter;
    this.isFilterSheetVisible = true;
  }

  private resetDraftFilters(): void {
    this.draftTypeFilter = AssignmentTypeFilter.ALL;
    this.draftSubjectCode = 'ALL';
    this.draftDateFilter = AssignmentDateFilter.ALL;
  }

  private applyFilters(): void {
    this.typeFilter = this.draftTypeFilter;
    this.subjectCode = this.draftSubjectCode;
    this.dateFilter = this.draftDateFilter;
    this.rebuildResults();
    this.isFilterSheetVisible = false;
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
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.TERTIARY_TEXT);
      Row({ space: 3 }) {
        Text(value)
          .fontSize(13)
          .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(active ? AppTheme.PRIMARY : AppTheme.TEXT);
        Text('⌄')
          .fontSize(11)
          .fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      }
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${label}：${value}，点击筛选`)
    .onClick(() => this.openFilterSheet());
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
      Text(this.hasActiveFilters() ? '筛选中' : '筛选')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasActiveFilters() ? AppTheme.PRIMARY : AppTheme.TEXT)
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 14, right: 14 })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('打开筛选面板')
        .onClick(() => this.openFilterSheet());
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .bindSheet($$this.isFilterSheetVisible, this.FilterSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      showClose: false,
      dragBar: true,
      backgroundColor: AppTheme.SURFACE
    });
  }

  @Builder
  private OptionChip(label: string, selected: boolean, action: () => void) {
    Text(label)
      .fontSize(14)
      .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(selected ? AppTheme.PRIMARY : AppTheme.TEXT)
      .constraintSize({ minWidth: 86, minHeight: AppTheme.MIN_TOUCH_TARGET })
      .textAlign(TextAlign.Center)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(selected ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .border({ width: selected ? 1 : 0, color: selected ? AppTheme.PRIMARY : Color.Transparent })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(selected ? `${label}，已选择` : label)
      .onClick(action);
  }

  @Builder
  private FilterSheet() {
    Column() {
      Scroll() {
        Column({ space: 22 }) {
          Row() {
            Column({ space: 3 }) {
              Text('筛选作业')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT);
              Text('选择条件后点击查询，列表才会更新。')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .alignItems(HorizontalAlign.Start);
            Blank();
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('类型').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.OptionChip('全部', this.draftTypeFilter === AssignmentTypeFilter.ALL,
                () => this.draftTypeFilter = AssignmentTypeFilter.ALL);
              this.OptionChip('课内', this.draftTypeFilter === AssignmentTypeFilter.SCHOOL,
                () => this.draftTypeFilter = AssignmentTypeFilter.SCHOOL);
              this.OptionChip('课外', this.draftTypeFilter === AssignmentTypeFilter.EXTRA,
                () => this.draftTypeFilter = AssignmentTypeFilter.EXTRA);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('截止时间').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.OptionChip('全部日期', this.draftDateFilter === AssignmentDateFilter.ALL,
                () => this.draftDateFilter = AssignmentDateFilter.ALL);
              this.OptionChip('今天', this.draftDateFilter === AssignmentDateFilter.TODAY,
                () => this.draftDateFilter = AssignmentDateFilter.TODAY);
              this.OptionChip('明天', this.draftDateFilter === AssignmentDateFilter.TOMORROW,
                () => this.draftDateFilter = AssignmentDateFilter.TOMORROW);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.OptionChip('本周', this.draftDateFilter === AssignmentDateFilter.THIS_WEEK,
                () => this.draftDateFilter = AssignmentDateFilter.THIS_WEEK);
              this.OptionChip('未定', this.draftDateFilter === AssignmentDateFilter.UNDATED,
                () => this.draftDateFilter = AssignmentDateFilter.UNDATED);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('科目').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.OptionChip('全部科目', this.draftSubjectCode === 'ALL', () => this.draftSubjectCode = 'ALL');
              this.OptionChip('语文', this.draftSubjectCode === 'CHINESE', () => this.draftSubjectCode = 'CHINESE');
              this.OptionChip('数学', this.draftSubjectCode === 'MATH', () => this.draftSubjectCode = 'MATH');
            }
            .width('100%');
            Row({ space: 8 }) {
              this.OptionChip('英语', this.draftSubjectCode === 'ENGLISH', () => this.draftSubjectCode = 'ENGLISH');
              this.OptionChip('其他', this.draftSubjectCode === 'OTHER', () => this.draftSubjectCode = 'OTHER');
            }
            .width('100%');
          }
          .width('100%');
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 8, bottom: 18 });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      Row({ space: 12 }) {
        Button('重置', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.resetDraftFilters());
        Button('查询', { type: ButtonType.Normal })
          .layoutWeight(2)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.applyFilters());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
    }
    .width('100%')
    .height('100%');
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
        Text('调整筛选条件后点击查询。').fontSize(13).fontColor(AppTheme.SUBTEXT);
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
    .height('100%')
    .scrollBar(BarState.Off);
  }
}
