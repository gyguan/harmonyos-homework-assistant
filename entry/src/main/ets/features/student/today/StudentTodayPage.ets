import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, StudentProfile, TodaySummary } from '../../../domain/model/HomeworkModels';

@Component
export struct StudentTodayPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop offlineMode: boolean = false;
  @Prop revision: number = 0;
  onOpenStudy: (assignmentId: string) => void = () => {};

  private student(): StudentProfile {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudent();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  private overdueAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.OVERDUE) result.push(item);
    }
    return result;
  }

  private summary(): TodaySummary {
    let items = this.assignments();
    let completed = 0;
    for (let item of items) {
      if (item.status === AssignmentStatus.COMPLETED) completed++;
    }
    let next = this.nextAssignment();
    return { completed: completed, total: items.length, nextAssignmentId: next === null ? '' : next.id };
  }

  private nextAssignment(): Assignment | null {
    let priorities: AssignmentStatus[] = [
      AssignmentStatus.IN_PROGRESS,
      AssignmentStatus.PAUSED,
      AssignmentStatus.NEEDS_REWORK,
      AssignmentStatus.OVERDUE,
      AssignmentStatus.NOT_STARTED,
      AssignmentStatus.READY_TO_SUBMIT
    ];
    let items = this.assignments();
    for (let status of priorities) {
      for (let item of items) {
        if (item.status === status) return item;
      }
    }
    return null;
  }

  private isRecommended(assignment: Assignment): boolean {
    let next = this.nextAssignment();
    return next !== null && next.id === assignment.id;
  }

  private actionLabel(assignment: Assignment): string {
    if (assignment.status === AssignmentStatus.NOT_STARTED || assignment.status === AssignmentStatus.OVERDUE ||
      assignment.status === AssignmentStatus.NEEDS_REWORK) {
      return '开始作业';
    }
    if (assignment.status === AssignmentStatus.IN_PROGRESS) {
      return '继续完成';
    }
    if (assignment.status === AssignmentStatus.PAUSED) {
      return '继续作业';
    }
    if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      return '去提交';
    }
    if (assignment.status === AssignmentStatus.SUBMITTED) {
      return '查看提交';
    }
    if (assignment.status === AssignmentStatus.COMPLETED) {
      return '查看作业';
    }
    return '查看作业';
  }

  @Builder
  private OfflineBanner() {
    Row({ space: 10 }) {
      Text('离线')
        .fontSize(AppTheme.CAPTION_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.WARNING);
      Column({ space: 2 }) {
        Text('当前为离线状态').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('正在使用已缓存的今日作业。').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
    }
    .width('100%').padding(13).backgroundColor(AppTheme.WARNING_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private OverdueBanner() {
    if (this.overdueAssignments().length > 0) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill')).fontSize(20).fontColor([AppTheme.DANGER]);
        Column({ space: 3 }) {
          Text(`有 ${this.overdueAssignments().length} 项昨天或更早的作业还没完成`)
            .width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('先处理逾期任务，再开始新的作业。')
            .width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      }
      .width('100%').padding(13).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private ProgressHero() {
    Row({ space: 14 }) {
      Column({ space: 5 }) {
        Text('今日完成').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        Row({ space: 7 }) {
          Text(`${this.summary().completed}`)
            .fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`/ ${this.summary().total}`)
            .fontSize(15).fontColor(AppTheme.SUBTEXT).margin({ top: 10 });
        }
      }.alignItems(HorizontalAlign.Start);
      Column({ space: 8 }) {
        Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
          .width('100%').height(7).color(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT);
        Text('完成一项就离今天的目标更近一步。')
          .width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
    }
    .width('100%').padding(16).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private AssignmentChoice(item: Assignment) {
    Column({ space: 4 }) {
      if (this.isRecommended(item)) {
        Text('小伴推荐')
          .width('100%')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      AssignmentListItem({
        assignment: item,
        onOpen: () => this.onOpenStudy(item.id)
      });
    }
    .width('100%');
  }

  @Builder
  private AssignmentListPane() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今天的作业').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('可以按推荐顺序，也可以自己选择').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }.alignItems(HorizontalAlign.Start);
        Blank();
        Text(`${this.assignments().length} 项`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Column({ space: 7 }) {
        ForEach(this.assignments(), (item: Assignment) => {
          this.AssignmentChoice(item);
        }, (item: Assignment) => item.id);
      }.width('100%');
    }.width('100%');
  }

  @Builder
  private NextAssignmentPane() {
    if (this.nextAssignment() === null) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(30).fontColor([AppTheme.SUCCESS]);
        Text('今天的主要任务已经完成')
          .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('可以休息一下，或者和家长一起检查已经提交的作业。')
          .width('100%').fontSize(AppTheme.BODY_SIZE).lineHeight(21).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%').padding(18).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
    } else {
      Column({ space: 13 }) {
        Row() {
          Text('推荐下一项').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          Blank();
          Text(this.nextAssignment()!.dueText).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%');
        Text(this.nextAssignment()!.title).width('100%').fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text(this.nextAssignment()!.instruction).width('100%').fontSize(15).lineHeight(22).fontColor(AppTheme.SUBTEXT);
        if (this.nextAssignment()!.status === AssignmentStatus.NEEDS_REWORK && this.nextAssignment()!.reviewNote.length > 0) {
          Text(`家长提醒：${this.nextAssignment()!.reviewNote}`)
            .width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.DANGER)
            .padding(10).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
        }
        Row({ space: 8 }) {
          Text(this.nextAssignment()!.textbookRef).layoutWeight(1).fontSize(13).fontColor(AppTheme.PRIMARY);
          Text(`预计 ${this.nextAssignment()!.expectedMinutes} 分钟`)
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.WARNING);
        }.width('100%');
        Button(this.actionLabel(this.nextAssignment()!), { type: ButtonType.Normal })
          .width('100%').height(AppTheme.BUTTON_HEIGHT).borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(16).fontWeight(FontWeight.Medium).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenStudy(this.nextAssignment()!.id));
      }
      .width('100%').padding(18).backgroundColor(AppTheme.PRIMARY_FAINT).borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text(`晚上好，${this.student().name}`).fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`${this.student().grade} · ${this.student().className} · ${this.student().semester}`)
            .fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%').alignItems(HorizontalAlign.Start);

        if (this.offlineMode) this.OfflineBanner();
        this.OverdueBanner();
        this.ProgressHero();

        if (this.sizeClass === WindowSizeClass.COMPACT) {
          this.NextAssignmentPane();
          this.AssignmentListPane();
        } else {
          Row({ space: 20 }) {
            Column() { this.AssignmentListPane(); }.width(this.sizeClass === WindowSizeClass.EXPANDED ? '40%' : '44%');
            Column() { this.NextAssignmentPane(); }.layoutWeight(1);
          }.width('100%').alignItems(VerticalAlign.Top);
        }
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
