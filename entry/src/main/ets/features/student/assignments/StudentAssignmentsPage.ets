import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate, DueDateFilterKey } from '../../../domain/service/AssignmentDueDate';

@Component
export struct StudentAssignmentsPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private subjectFilter: string = 'ALL';
  @State private dateFilter: DueDateFilterKey = DueDateFilterKey.ALL;
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

  private actionLabel(item: Assignment): string {
    switch (item.status) {
      case AssignmentStatus.NOT_STARTED:
      case AssignmentStatus.OVERDUE:
      case AssignmentStatus.NEEDS_REWORK:
        return '开始作业';
      case AssignmentStatus.IN_PROGRESS:
      case AssignmentStatus.PAUSED:
        return '继续作业';
      case AssignmentStatus.READY_TO_SUBMIT:
        return '去提交';
      case AssignmentStatus.SUBMITTED:
        return '查看提交';
      case AssignmentStatus.COMPLETED:
        return '查看作业';
      default:
        return '查看';
    }
  }

  @Builder
  private SubjectFilterChip(key: string, label: string) {
    Text(`${label} ${this.subjectCount(key)}`)
      .layoutWeight(1)
      .height(36)
      .textAlign(TextAlign.Center)
      .fontSize(AppTheme.CAPTION_SIZE)
      .fontWeight(this.subjectFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.subjectFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .padding({ top: 9, bottom: 9 })
      .backgroundColor(this.subjectFilter === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .onClick(() => this.subjectFilter = key);
  }

  @Builder
  private SubjectFilterBar() {
    Row({ space: 7 }) {
      this.SubjectFilterChip('ALL', '全部');
      this.SubjectFilterChip(Subject.CHINESE, '语文');
      this.SubjectFilterChip(Subject.MATH, '数学');
      this.SubjectFilterChip(Subject.ENGLISH, '英语');
    }.width('100%');
  }

  @Builder
  private DateFilterChip(key: DueDateFilterKey, label: string) {
    Text(`${label} ${this.dateCount(key)}`)
      .layoutWeight(1)
      .height(36)
      .textAlign(TextAlign.Center)
      .fontSize(AppTheme.CAPTION_SIZE)
      .fontWeight(this.dateFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.dateFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .padding({ top: 9, bottom: 9 })
      .backgroundColor(this.dateFilter === key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .onClick(() => this.dateFilter = key);
  }

  @Builder
  private DateFilterBar() {
    Row({ space: 6 }) {
      this.DateFilterChip(DueDateFilterKey.ALL, '全部');
      this.DateFilterChip(DueDateFilterKey.TODAY, '今天');
      this.DateFilterChip(DueDateFilterKey.TOMORROW, '明天');
      this.DateFilterChip(DueDateFilterKey.THIS_WEEK, '本周');
      this.DateFilterChip(DueDateFilterKey.OVERDUE, '逾期');
    }.width('100%');
  }

  @Builder
  private FilterPanel() {
    Column({ space: 7 }) {
      Text('科目').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
      this.SubjectFilterBar();
      Text('截止').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
      this.DateFilterBar();
    }.width('100%');
  }

  @Builder
  private Task(item: Assignment) {
    Column({ space: 8 }) {
      AssignmentCard({ assignment: item });
      Row() {
        Blank();
        Button(this.actionLabel(item), { type: ButtonType.Normal })
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .padding({ left: 18, right: 18 })
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.onOpenStudy(item.id));
      }.width('100%');
    }.width('100%');
  }

  @Builder
  private Section(title: string, description: string, items: Assignment[]) {
    if (items.length > 0) {
      Column({ space: AppTheme.ITEM_GAP }) {
        Row() {
          Column({ space: 3 }) {
            Text(title).fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text(description).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }.alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${items.length} 项`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%');
        ForEach(items, (item: Assignment) => { this.Task(item); }, (item: Assignment) => item.id);
      }.width('100%');
    }
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('我的作业').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('按科目和截止日期定位，再看需要处理、待开始、已提交和已完成。')
            .fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%').alignItems(HorizontalAlign.Start);

        this.FilterPanel();

        this.Section('需要处理', '正在做、已暂停、需要订正或已经逾期',
          this.inStatuses([AssignmentStatus.IN_PROGRESS, AssignmentStatus.PAUSED,
            AssignmentStatus.NEEDS_REWORK, AssignmentStatus.OVERDUE, AssignmentStatus.READY_TO_SUBMIT]));
        this.Section('待开始', '还没有开始的作业', this.inStatuses([AssignmentStatus.NOT_STARTED]));
        this.Section('已提交 · 待家长验收', '已经交上去，等待家长确认或提出订正',
          this.inStatuses([AssignmentStatus.SUBMITTED]));
        this.Section('已完成', '家长已经确认完成', this.inStatuses([AssignmentStatus.COMPLETED]));

        if (this.filteredAssignments().length === 0) {
          Text(this.assignments().length === 0 ? '暂时没有作业' : '当前科目和日期下暂时没有作业')
            .width('100%').padding(AppTheme.CARD_PADDING)
            .fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT)
            .backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);
        }
      }.width('100%').padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }.width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
