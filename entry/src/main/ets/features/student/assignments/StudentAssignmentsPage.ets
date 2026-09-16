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
  onOpenDetail: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: StudentAssignmentsViewModel =
    new StudentAssignmentsViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    await this.viewModel.refresh();
    this.refreshRevision++;
  }

  private touchRevision(): number {
    return this.revision + this.refreshRevision;
  }

  private filteredAssignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    return this.viewModel.assignments(this.typeFilter, this.subjectCode, this.dateFilter);
  }

  private allAssignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    return this.viewModel.assignments(AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL);
  }

  private inStatuses(statuses: AssignmentStatus[]): Assignment[] {
    let currentRevision = this.touchRevision();
    return this.viewModel.assignments(this.typeFilter, this.subjectCode, this.dateFilter, statuses);
  }

  private typeCount(typeFilter: AssignmentTypeFilter): number {
    let currentRevision = this.touchRevision();
    return this.viewModel.count(typeFilter, this.subjectCode, this.dateFilter);
  }

  private subjectCount(subjectCode: string): number {
    let currentRevision = this.touchRevision();
    return this.viewModel.count(this.typeFilter, subjectCode, this.dateFilter);
  }

  private dateCount(dateFilter: AssignmentDateFilter): number {
    let currentRevision = this.touchRevision();
    return this.viewModel.count(this.typeFilter, this.subjectCode, dateFilter);
  }

  @Builder
  private TypeChip(key: AssignmentTypeFilter, label: string) {
    Text(`${label} ${this.typeCount(key)}`)
      .fontSize(13)
      .fontWeight(this.typeFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.typeFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(this.typeFilter === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.typeFilter === key ? `${label}，已选择` : label)
      .onClick(() => this.typeFilter = key);
  }

  @Builder
  private SubjectChip(key: string, label: string) {
    Text(`${label} ${this.subjectCount(key)}`)
      .fontSize(13)
      .fontWeight(this.subjectCode === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.subjectCode === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.subjectCode === key ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.subjectCode === key ? `${label}，已选择` : label)
      .onClick(() => this.subjectCode = key);
  }

  @Builder
  private DateChip(key: AssignmentDateFilter, label: string) {
    Text(`${label} ${this.dateCount(key)}`)
      .fontSize(12)
      .fontWeight(this.dateFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.dateFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.dateFilter === key ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.dateFilter === key ? `${label}，已选择` : label)
      .onClick(() => this.dateFilter = key);
  }

  @Builder
  private FilterPanel() {
    Column({ space: 10 }) {
      Scroll() {
        Row({ space: 8 }) {
          this.TypeChip(AssignmentTypeFilter.ALL, '全部');
          this.TypeChip(AssignmentTypeFilter.SCHOOL, '课内');
          this.TypeChip(AssignmentTypeFilter.EXTRA, '课外');
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      Scroll() {
        Row({ space: 4 }) {
          this.DateChip(AssignmentDateFilter.ALL, '全部日期');
          this.DateChip(AssignmentDateFilter.TODAY, '今天');
          this.DateChip(AssignmentDateFilter.TOMORROW, '明天');
          this.DateChip(AssignmentDateFilter.THIS_WEEK, '本周');
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      Scroll() {
        Row({ space: 4 }) {
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
    if (this.filteredAssignments().length === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square'))
          .fontSize(30)
          .fontColor([AppTheme.TERTIARY_TEXT]);
        Text(this.allAssignments().length === 0 ? '暂时没有作业' : '当前筛选下没有作业')
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
      this.Section('需要处理', '进行中、待订正、逾期或待提交',
        this.inStatuses([AssignmentStatus.IN_PROGRESS, AssignmentStatus.PAUSED,
          AssignmentStatus.NEEDS_REWORK, AssignmentStatus.OVERDUE, AssignmentStatus.READY_TO_SUBMIT]));
      this.Section('待开始', '还没有开始的作业', this.inStatuses([AssignmentStatus.NOT_STARTED]));
      this.Section('已提交', '等待家长确认', this.inStatuses([AssignmentStatus.SUBMITTED]));
      this.Section('已完成', '已经完成并验收', this.inStatuses([AssignmentStatus.COMPLETED]));
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
            Text('按类型、日期和科目筛选，找到要完成的任务。').fontSize(13).fontColor(AppTheme.SUBTEXT);
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
