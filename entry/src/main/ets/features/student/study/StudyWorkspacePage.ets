import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { MockData } from '../../../data/MockData';
import { Assignment } from '../../../domain/model/HomeworkModels';

@Component
export struct StudyWorkspacePage {
  @Prop sizeClass: WindowSizeClass;
  onBack: () => void = () => {};

  @Builder
  private TaskRail() {
    Column({ space: 10 }) {
      Text('今天').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      ForEach(MockData.assignments.slice(0, 3), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private StudyContent() {
    Scroll() {
      Column({ space: 14 }) {
        Text('数学 · 练习册 P26')
          .width('100%')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(MockData.assignments[0].instruction)
          .width('100%')
          .fontSize(15)
          .fontColor(AppTheme.SUBTEXT);

        Column({ space: 8 }) {
          Text('▶ 老师讲解视频 · 03:24').width('100%').fontSize(15);
          Text('PDF 练习说明 · 2 页').width('100%').fontSize(15);
          Text('📘 ' + MockData.assignments[0].textbookRef).width('100%').fontSize(14).fontColor(AppTheme.PRIMARY);
        }
        .width('100%')
        .padding(18)
        .borderRadius(16)
        .backgroundColor('#F4F6F9');

        Button('拍照提交')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.PRIMARY);
      }
      .width('100%');
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private TutorPane() {
    Column({ space: 12 }) {
      Text('问小伴')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text('你现在卡在哪一道题？可以拍给我看，也可以直接说。')
        .width('100%')
        .padding(14)
        .fontSize(14)
        .fontColor(AppTheme.TEXT)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(14);
      Text('提示策略：先给一点提示，不直接说答案。')
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
      TextInput({ placeholder: '输入问题…' })
        .width('100%')
        .height(44)
        .backgroundColor('#F7F8FA');
      Row({ space: 8 }) {
        Button('🎙 语音').layoutWeight(1);
        Button('📷 拍题').layoutWeight(1);
      }
      .width('100%');
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.onBack());
        Blank();
        Text('20:30 前完成').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.sizeClass === WindowSizeClass.EXPANDED) {
        Row({ space: 14 }) {
          Column() { this.TaskRail(); }.width('20%');
          Column() { this.StudyContent(); }.width('50%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else if (this.sizeClass === WindowSizeClass.MEDIUM) {
        Row({ space: 14 }) {
          Column() { this.StudyContent(); }.width('64%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else {
        Scroll() {
          Column({ space: 14 }) {
            this.StudyContent();
            this.TutorPane();
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
