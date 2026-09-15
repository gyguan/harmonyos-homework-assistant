import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate, DueDateFilterKey } from '../../../domain/service/AssignmentDueDate';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct StudentAssignmentsPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private subjectFilter: string = 'ALL';
  @State private dateFilter: DueDateFilterKey = DueDateFilterKey.ALL;
  @State private selectedAssignmentId: string = '';
  onOpenStudy: (assignmentId: string) => void = () => {};

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  private matchesSubject(item: Assignment, subject: string): boolean {
    return subject === 'ALL' || item.subject === subject;
  }

  private filteredAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, this.subjectFilter) && AssignmentDueDate.matches(item, this.dateFilter)) result.push(item);
    }
    return result;
  }

  private selectedAssignment(): Assignment | null {
    if (this.selectedAssignmentId.length === 0) return null;
    return HomeworkStore.instance.getAssignment(this.selectedAssignmentId);
  }

  private subjectCount(subject: string): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, subject) && AssignmentDueDate.matches(item, this.dateFilter)) count++;
    }
    return count;
  }

  private dateCount(dateFilter: DueDateFilterKey): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, this.subjectFilter) && AssignmentDueDate.matches(item, dateFilter)) count++;
    }
    return count;
  }

  private inStatuses(statuses: AssignmentStatus[]): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.filteredAssignments()) {
      for (let status of statuses) {
        if (item.status === status) {
          result.push(item);
          break;
        }
      }
    }
    return result;
  }

  private openAssignment(item: Assignment): void {
    if (this.sizeClass === WindowSizeClass.COMPACT) {
      this.onOpenStudy(item.id);
      return;
    }
    this.selectedAssignmentId = item.id;
  }

  @Builder
  private SubjectTab(key: string, label: string) {
    Column({ space: 5 }) {
      Text(`${label} ${this.subjectCount(key)}`)
        .fontSize(13)
        .fontWeight(this.subjectFilter === key ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.subjectFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      Divider()
        .width('100%')
        .strokeWidth(this.subjectFilter === key ? 2 : 0)
        .color(this.subjectFilter === key ? AppTheme.PRIMARY : Color.Transparent);
    }
    .height(36)
    .padding({ left: 4, right: 4 })
    .justifyContent(FlexAlign.End)
    .onClick(() => this.subjectFilter = key);
  }

  @Builder
  private DateTab(key: DueDateFilterKey, label: string) {
    Text(`${label} ${this.dateCount(key)}`)
      .fontSize(12)
      .fontWeight(this.dateFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.dateFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.dateFilter === key ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .onClick(() => this.dateFilter = key);
  }

  @Builder
  private FilterPanel() {
    Column({ space: 8 }) {
      Scroll() {
        Row({ space: 18 }) {
          this.SubjectTab('ALL', '全部');
          this.SubjectTab(Subject.CHINESE, '语文');
          this.SubjectTab(Subject.MATH, '数学');
          this.SubjectTab(Subject.ENGLISH, '英语');
        }
        .padding({ left: 2, right: 2 });
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      Scroll() {
        Row({ space: 4 }) {
          this.DateTab(DueDateFilterKey.ALL, '全部日期');
          this.DateTab(DueDateFilterKey.TODAY, '今天');
          this.DateTab(DueDateFilterKey.TOMORROW, '明天');
          this.DateTab(DueDateFilterKey.THIS_WEEK, '本周');
          this.DateTab(DueDateFilterKey.OVERDUE, '逾期');
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .padding({ top: 2, bottom: 4 });
  }

  @Builder
  private Section(title: string, description: string, items: Assignment[]) {
    if (items.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text(title)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text(description)
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${items.length}`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');

        Column({ space: 6 }) {
          ForEach(items, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.selectedAssignmentId === item.id,
              onOpen: () => this.openAssignment(item)
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
        Text(this.assignments().length === 0 ? '暂时没有作业' : '当前筛选下没有作业')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('换一个科目或截止日期看看。')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ top: 28, bottom: 28 });
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

  @Builder
  private PageHeader() {
    Column({ space: 4 }) {
      Text('我的作业')
        .fontSize(AppTheme.PAGE_TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text('按科目和日期找到任务，点整行即可继续。')
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private DetailPane() {
    if (this.selectedAssignment() === null) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square'))
          .fontSize(34)
          .fontColor([AppTheme.TERTIARY_TEXT]);
        Text('选择一项作业')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('在左侧选择作业后，可在这里查看任务摘要并进入学习空间。')
          .fontSize(14)
          .lineHeight(21)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(32);
    } else {
      Scroll() {
        Column({ space: 18 }) {
          Row() {
            Text(this.selectedAssignment()!.subject)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY);
            Blank();
            Text(AssignmentStateMachine.label(this.selectedAssignment()!.status))
              .fontSize(13)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          Text(this.selectedAssignment()!.title)
            .width('100%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);

          Text(this.selectedAssignment()!.instruction)
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(AppTheme.SUBTEXT);

          Column({ space: 12 }) {
            Row() {
              Text('截止时间').fontSize(13).fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(this.selectedAssignment()!.dueText).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            }.width('100%');
            Divider().color(AppTheme.DIVIDER);
            Row() {
              Text('预计用时').fontSize(13).fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(`${this.selectedAssignment()!.expectedMinutes} 分钟`).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            }.width('100%');
            Divider().color(AppTheme.DIVIDER);
            Row() {
              Text('教材 / 页码').fontSize(13).fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(this.selectedAssignment()!.textbookRef.length > 0 ? this.selectedAssignment()!.textbookRef : '未设置')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
            }.width('100%');
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          if (this.selectedAssignment()!.reviewNote.length > 0) {
            Column({ space: 4 }) {
              Text('家长提醒')
                .width('100%')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.WARNING);
              Text(this.selectedAssignment()!.reviewNote)
                .width('100%')
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppTheme.TEXT);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.WARNING_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          Button('进入学习空间', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => this.onOpenStudy(this.selectedAssignment()!.id));
        }
        .width('100%')
        .padding(this.sizeClass === WindowSizeClass.EXPANDED ? 28 : 22);
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private CompactLayout() {
    Scroll() {
      Column({ space: 18 }) {
        this.PageHeader();
        this.FilterPanel();
        this.AssignmentSections();
      }
      .width('100%')
      .padding(AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private PadLayout() {
    Row() {
      Scroll() {
        Column({ space: 18 }) {
          this.PageHeader();
          this.FilterPanel();
          this.AssignmentSections();
        }
        .width('100%')
        .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
      }
      .width(this.sizeClass === WindowSizeClass.EXPANDED ? '38%' : '44%')
      .height('100%')
      .backgroundColor(AppTheme.BACKGROUND);

      Divider().vertical(true).height('100%').color(AppTheme.DIVIDER);

      Column() {
        this.DetailPane();
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(AppTheme.SURFACE);
    }
    .width('100%')
    .height('100%');
  }

  build() {
    if (this.sizeClass === WindowSizeClass.COMPACT) {
      this.CompactLayout();
    } else {
      this.PadLayout();
    }
  }
}
