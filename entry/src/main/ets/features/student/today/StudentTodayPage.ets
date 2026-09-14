import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { MockData } from '../../../data/MockData';
import { Assignment } from '../../../domain/model/HomeworkModels';

@Component
export struct StudentTodayPage {
  @Prop sizeClass: WindowSizeClass;
  onOpenStudy: (assignmentId: string) => void = () => {};

  @Builder
  private ProgressHero() {
    Column({ space: 8 }) {
      Text('今日完成度').fontSize(13).fontColor('#FFFFFFCC');
      Text(`${MockData.todaySummary.completed} / ${MockData.todaySummary.total}`)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White);
      Text('完成今天的任务后，就可以休息啦')
        .fontSize(14)
        .fontColor(Color.White);
      Progress({ value: MockData.todaySummary.completed, total: MockData.todaySummary.total, type: ProgressType.Linear })
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
      ForEach(MockData.assignments.slice(0, 3), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private NextAssignmentPane() {
    Column({ space: 14 }) {
      Text('下一项')
        .width('100%')
        .fontSize(14)
        .fontColor(AppTheme.SUBTEXT);
      Text(MockData.assignments[0].title)
        .width('100%')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(MockData.assignments[0].instruction)
        .width('100%')
        .fontSize(15)
        .fontColor(AppTheme.SUBTEXT);
      Text(MockData.assignments[0].textbookRef)
        .width('100%')
        .fontSize(13)
        .fontColor(AppTheme.PRIMARY);
      Button('继续完成')
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor(AppTheme.PRIMARY)
        .onClick(() => this.onOpenStudy(MockData.assignments[0].id));
    }
    .width('100%')
    .padding(22)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(20)
    .border({ width: 1, color: AppTheme.BORDER });
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
            Text('今天还有 2 项作业需要完成')
              .fontSize(14)
              .fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
        }
        .width('100%');

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
