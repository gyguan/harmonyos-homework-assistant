import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, StudentProfile, TodaySummary } from '../../../domain/model/HomeworkModels';

@Component
export struct ParentDashboardPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  onOpenImport: () => void = () => {};

  private student(): StudentProfile {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudent();
  }

  private summary(): TodaySummary {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getTodaySummary();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  @Builder
  private TodayCard() {
    Column({ space: 10 }) {
      Text(`${this.student().name}今天`)
        .width('100%')
        .fontSize(14)
        .fontColor('#FFFFFFCC');
      Text(`${this.summary().completed} / ${this.summary().total} 已完成`)
        .width('100%')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White);
      Text('不用盯过程，只看今天还有什么没完成。')
        .width('100%')
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
  private AssignmentProgress() {
    Column({ space: 10 }) {
      Text('今天的作业').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private ImportCard() {
    Column({ space: 10 }) {
      Text(`给 ${this.student().name} 收作业`)
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(`当前班级：${this.student().className}。把这个班老师发来的截图或文字交给小伴，确认后只进入 ${this.student().name} 的作业。`)
        .width('100%')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppTheme.SUBTEXT);
      Button('导入老师作业')
        .width('100%')
        .height(48)
        .backgroundColor(AppTheme.PRIMARY)
        .onClick(() => this.onOpenImport());
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
          Text('作业进度').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`${this.student().name} · ${this.student().grade} · ${this.student().className} · ${this.student().semester}`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        this.TodayCard();

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
            Column() { this.AssignmentProgress(); }.width('64%');
            Column() { this.ImportCard(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.AssignmentProgress();
          this.ImportCard();
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
