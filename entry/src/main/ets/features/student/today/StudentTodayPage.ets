import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, TodaySummary } from '../../../domain/model/HomeworkModels';

@Component
export struct StudentTodayPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop offlineMode: boolean = false;
  @Prop revision: number = 0;
  onOpenStudy: (assignmentId: string) => void = () => {};

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
    Row({ space: 8 }) {
      Text('离线')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.WARNING);
      Text('正在使用已缓存的今日作业，提交将在联网后同步。')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFF8E7')
    .borderRadius(14);
  }

  @Builder
  private ProgressHero() {
    Column({ space: 8 }) {
      Text('今日完成度').fontSize(13).fontColor('#FFFFFFCC');
      Text(`${this.summary().completed} / ${this.summary().total}`)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White);
      Text('完成今天的任务后，就可以休息啦')
        .fontSize(14)
        .fontColor(Color.White);
      Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
        .width('100%')
        .height(8)
        .color(Color.White)
        .backgroundColor('#FFFFFF44');
    }
    .width('100%')
    .padding(20)
    .borderRadius(22)
    .linearGradient({
      angle: 135,
      colors: [[AppTheme.PRIMARY, 0.0], ['#6D8DFF', 1.0]]
    });
  }

  @Builder
  private AssignmentListPane() {
    Column({ space: 12 }) {
      Text('今天的作业')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
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
        Text('今天的主要任务已经完成')
          .width('100%')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('可以休息一下，或者和家长一起检查已经提交的作业。')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(22)
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(20)
      .border({ width: 1, color: AppTheme.BORDER });
    } else {
      Column({ space: 14 }) {
        Text('下一项')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.SUBTEXT);
        Text(this.nextAssignment()!.title)
          .width('100%')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(this.nextAssignment()!.instruction)
          .width('100%')
          .fontSize(15)
          .fontColor(AppTheme.SUBTEXT);
        Text(this.nextAssignment()!.textbookRef)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.PRIMARY);
        Button(this.actionLabel(this.nextAssignment()!))
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppTheme.PRIMARY)
          .onClick(() => this.onOpenStudy(this.nextAssignment()!.id));
      }
      .width('100%')
      .padding(22)
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(20)
      .border({ width: 1, color: AppTheme.BORDER });
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 4 }) {
            Text('晚上好，小宇 👋')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
            Text(`今天共 ${this.summary().total} 项作业`)
              .fontSize(14)
              .fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
        }
        .width('100%');

        if (this.offlineMode) {
          this.OfflineBanner();
        }

        this.ProgressHero();

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
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
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
