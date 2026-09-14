import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
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
    return HomeworkStore.instance.getTodayAssignments();
  }

  private summary(): TodaySummary {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getTodaySummary();
  }

  private nextAssignment(): Assignment | null {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getNextAssignment();
  }

  private actionLabel(assignment: Assignment): string {
    if (assignment.status === AssignmentStatus.NOT_STARTED || assignment.status === AssignmentStatus.OVERDUE) {
      return '开始作业';
    }
    if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      return '去提交';
    }
    if (assignment.status === AssignmentStatus.SUBMITTED) {
      return '查看提交';
    }
    return '继续完成';
  }

  @Builder
  private OfflineBanner() {
    Row({ space: 10 }) {
      Text('离线')
        .fontSize(AppTheme.CAPTION_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.WARNING)
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CHIP_RADIUS);
      Column({ space: 2 }) {
        Text('当前为离线状态')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('正在使用已缓存的今日作业。')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.WARNING_SOFT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private ProgressHero() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 5 }) {
          Text('今日完成')
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          Text(`${this.summary().completed} / ${this.summary().total}`)
            .width('100%')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(30)
          .fontColor([AppTheme.PRIMARY]);
      }
      .width('100%');

      Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
        .width('100%')
        .height(7)
        .color(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT);

      Text('只管完成下一项，其他事情交给小伴记住。')
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private AssignmentListPane() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Row() {
        Text('今天的作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.assignments().length} 项`)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private NextAssignmentPane() {
    if (this.nextAssignment() === null) {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(30)
          .fontColor([AppTheme.SUCCESS]);
        Text('今天的主要任务已经完成')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('可以休息一下，或者和家长一起检查已经提交的作业。')
          .width('100%')
          .fontSize(AppTheme.BODY_SIZE)
          .lineHeight(21)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(AppTheme.CARD_PADDING)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CARD_RADIUS);
    } else {
      Column({ space: 13 }) {
        Row() {
          Text('下一项')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          Blank();
          Text(this.nextAssignment()!.dueText)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        Text(this.nextAssignment()!.title)
          .width('100%')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(this.nextAssignment()!.instruction)
          .width('100%')
          .fontSize(15)
          .lineHeight(22)
          .fontColor(AppTheme.SUBTEXT);
        Text(this.nextAssignment()!.textbookRef)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.PRIMARY);
        Button(this.actionLabel(this.nextAssignment()!), { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenStudy(this.nextAssignment()!.id));
      }
      .width('100%')
      .padding(AppTheme.CARD_PADDING)
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CARD_RADIUS);
    }
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text(`晚上好，${this.student().name}`)
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(`${this.student().grade} · ${this.student().className} · ${this.student().semester}`)
            .fontSize(AppTheme.BODY_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.offlineMode) {
          this.OfflineBanner();
        }

        this.ProgressHero();

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 20 }) {
            Column() { this.AssignmentListPane(); }.width('38%');
            Column() { this.NextAssignmentPane(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.NextAssignmentPane();
          this.AssignmentListPane();
        }
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
