import { AppTheme } from '../common/theme/AppTheme';
import { HomeworkStore } from '../data/HomeworkStore';
import { StudentProfile } from '../domain/model/HomeworkModels';

@Component
export struct PersonEntryPage {
  @Prop revision: number = 0;
  onSelectParent: () => void = () => {};
  onSelectStudent: (studentId: string) => void = () => {};

  private students(): StudentProfile[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudents();
  }

  @Builder
  private BrandHeader() {
    Column({ space: 10 }) {
      Text('伴')
        .width(52)
        .height(52)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 12 })
        .backgroundColor(AppTheme.PRIMARY)
        .borderRadius(16);
      Text('小伴作业')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text('今天是谁在使用？')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text('进入后身份固定，孩子只看到自己的作业。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 18 });
  }

  @Builder
  private ParentRow() {
    Row({ space: 13 }) {
      Text('家')
        .width(40)
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 10 })
        .backgroundColor(AppTheme.PRIMARY)
        .borderRadius(12);
      Column({ space: 3 }) {
        Text('家长')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('收作业、确认任务、查看孩子完成情况')
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .onClick(() => this.onSelectParent());
  }

  @Builder
  private StudentRow(student: StudentProfile) {
    Row({ space: 13 }) {
      Text(student.name.length > 0 ? student.name.substring(0, 1) : '伴')
        .width(40)
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 10 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(12);
      Column({ space: 3 }) {
        Text(student.name)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(`${student.grade} · ${student.className}`)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .onClick(() => this.onSelectStudent(student.id));
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        this.BrandHeader();

        Text('家长')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ left: 4 });
        Column() {
          this.ParentRow();
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);

        Text('孩子')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ left: 4, top: 8 });
        Column() {
          ForEach(this.students(), (student: StudentProfile, index: number) => {
            this.StudentRow(student);
            if (index < this.students().length - 1) {
              Divider().color(AppTheme.DIVIDER);
            }
          }, (student: StudentProfile) => student.id);
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);

        Text('选择后进入对应空间。家长可以管理多个孩子，学生空间不会切换到其他家庭成员。')
          .width('100%')
          .padding({ top: 8, left: 4, right: 4 })
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .constraintSize({ maxWidth: 560 })
      .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 48, bottom: 40 });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
