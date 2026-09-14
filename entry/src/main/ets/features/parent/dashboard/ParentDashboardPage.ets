import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, DashboardSummary } from '../../../domain/model/HomeworkModels';

@Component
export struct ParentDashboardPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;

  private dashboard(): DashboardSummary {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getDashboardSummary();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

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
  private KpiSection() {
    if (this.sizeClass === WindowSizeClass.COMPACT) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.Kpi('已完成', this.dashboard().completed, AppTheme.SUCCESS);
          this.Kpi('进行中', this.dashboard().inProgress, AppTheme.WARNING);
        }
        .width('100%');
        Row({ space: 10 }) {
          this.Kpi('未开始', this.dashboard().notStarted, AppTheme.SUBTEXT);
          this.Kpi('已提交', this.dashboard().submitted, AppTheme.SUCCESS);
        }
        .width('100%');
      }
      .width('100%');
    } else {
      Row({ space: 10 }) {
        this.Kpi('已完成', this.dashboard().completed, AppTheme.SUCCESS);
        this.Kpi('进行中', this.dashboard().inProgress, AppTheme.WARNING);
        this.Kpi('未开始', this.dashboard().notStarted, AppTheme.SUBTEXT);
        this.Kpi('已提交', this.dashboard().submitted, AppTheme.SUCCESS);
      }
      .width('100%');
    }
  }

  @Builder
  private AssignmentProgress() {
    Column({ space: 10 }) {
      Text('全部作业').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private Attention() {
    Column({ space: 10 }) {
      Text('需要关注').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      if (this.dashboard().overdue > 0) {
        Text(`有 ${this.dashboard().overdue} 项作业已超时，建议优先处理。`)
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.DANGER);
      }
      if (this.dashboard().readyToSubmit > 0) {
        Text(`有 ${this.dashboard().readyToSubmit} 项已经做完，等待学生提交。`)
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.WARNING);
      }
      if (this.dashboard().needsRework > 0) {
        Text(`有 ${this.dashboard().needsRework} 项需要重做。`)
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.DANGER);
      }
      Text('所有统计都直接来自统一 Assignment 状态，不再维护页面级重复计数。')
        .width('100%')
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
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
          Text('状态来自本地 HomeworkStore · 刚刚更新').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        this.KpiSection();

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
