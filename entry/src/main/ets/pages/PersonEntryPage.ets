import { AppTheme } from '../common/theme/AppTheme';
import { HomeworkStore } from '../data/HomeworkStore';
import { StudentProfile } from '../domain/model/HomeworkModels';

@Component
export struct PersonEntryPage {
  onSelectParent: () => void = () => {};
  onSelectStudent: (studentId: string) => void = () => {};

  private students(): StudentProfile[] {
    return HomeworkStore.instance.getStudents();
  }

  @Builder
  private ParentCard() {
    Row({ space: 14 }) {
      Text('家')
        .width(48)
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .padding({ top: 12 })
        .backgroundColor(AppTheme.PRIMARY)
        .borderRadius(16);
      Column({ space: 4 }) {
        Text('家长')
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('收作业、确认任务、查看两个孩子的完成情况')
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('进入')
        .fontSize(13)
        .fontColor(AppTheme.PRIMARY);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER })
    .onClick(() => this.onSelectParent());
  }

  @Builder
  private StudentCard(student: StudentProfile) {
    Row({ space: 14 }) {
      Text(student.name.substring(0, 1))
        .width(48)
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 12 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(16);
      Column({ space: 4 }) {
        Text(student.name)
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(`${student.grade} · ${student.className}`)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('进入')
        .fontSize(13)
        .fontColor(AppTheme.PRIMARY);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER })
    .onClick(() => this.onSelectStudent(student.id));
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 8 }) {
          Text('小伴作业')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('谁在使用？')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('选择人员后进入对应空间，进入后身份保持不变。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 8 });

        Text('家长')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        this.ParentCard();

        Text('孩子')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ top: 6 });
        ForEach(this.students(), (student: StudentProfile) => {
          this.StudentCard(student);
        }, (student: StudentProfile) => student.id);

        Text('家长可以管理多个孩子；孩子只能进入自己的作业空间。')
          .width('100%')
          .fontSize(12)
          .lineHeight(19)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ top: 8 });
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 56, bottom: 40 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
