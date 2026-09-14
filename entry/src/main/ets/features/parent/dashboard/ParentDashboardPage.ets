import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { MockData } from '../../../data/MockData';
import { Assignment } from '../../../domain/model/HomeworkModels';

@Component
export struct ParentDashboardPage {
  @Prop sizeClass: WindowSizeClass;

  @Builder
  private Kpi(label: string, value: number, color: string) {
    Column({ space: 6 }) {
      Text(label).fontSize(12).fontColor(AppTheme.SUBTEXT);
      Text(value.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor(color);
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(16)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private AssignmentProgress() {
    Column({ space: 10 }) {
      Text('今日作业').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      ForEach(MockData.assignments.slice(0, 3), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private Attention() {
    Column({ space: 10 }) {
      Text('需要关注').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      Text('数学今天用时比近几天偏长，目前仍在正常截止时间内。')
        .width('100%')
        .fontSize(14)
        .fontColor(AppTheme.SUBTEXT);
      Text('AI Tutor 当前可用；没有需要家长立即介入的异常。')
        .width('100%')
        .fontSize(13)
        .fontColor(AppTheme.SUCCESS);
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('小宇今天的学习').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('最后同步：刚刚').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Row({ space: 10 }) {
          this.Kpi('已完成', MockData.dashboard.completed, AppTheme.SUCCESS);
          this.Kpi('进行中', MockData.dashboard.inProgress, AppTheme.WARNING);
          this.Kpi('未开始', MockData.dashboard.notStarted, AppTheme.SUBTEXT);
          if (this.sizeClass !== WindowSizeClass.COMPACT) {
            this.Kpi('超时', MockData.dashboard.overdue, AppTheme.DANGER);
          }
        }
        .width('100%');

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
            Column() { this.AssignmentProgress(); }.width('64%');
            Column() { this.Attention(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.AssignmentProgress();
          this.Attention();
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
