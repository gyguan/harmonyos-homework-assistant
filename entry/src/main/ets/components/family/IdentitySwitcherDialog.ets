import { AppTheme } from '../../common/theme/AppTheme';
import { TextAction, TextActionKind } from '../action/ActionControls';
import { StudentProfile } from '../../domain/model/HomeworkModels';
import { CenteredTextBadge } from './CenteredTextBadge';

@CustomDialog
export struct IdentitySwitcherDialog {
  controller: CustomDialogController;
  @Link students: StudentProfile[];
  @Link activeStudentId: string;
  @Link parentActive: boolean;
  onSelectParent: () => void = () => {};
  onSelectStudent: (studentId: string) => void = (_studentId: string) => {};

  private chooseParent(): void {
    this.onSelectParent();
    this.controller.close();
  }

  private chooseStudent(studentId: string): void {
    this.onSelectStudent(studentId);
    this.controller.close();
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('切换身份')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('选择家长或学生，切换后自动进入对应界面')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭身份选择',
          onAction: () => this.controller.close()
        });
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 12 }) {
          Text('家长')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUBTEXT);

          Row({ space: 12 }) {
            CenteredTextBadge({
              badgeText: '家',
              badgeWidth: 42,
              badgeHeight: 42,
              badgeFontSize: 16,
              badgeRadius: 14,
              badgeBold: true,
              badgeForeground: this.parentActive ? AppTheme.TEXT_ON_PRIMARY : AppTheme.PRIMARY,
              badgeBackground: this.parentActive ? AppTheme.PRIMARY : AppTheme.PRIMARY_SOFT
            });
            Column({ space: 3 }) {
              Text('家长')
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text('布置作业、查看进度、验收任务')
                .width('100%')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
            if (this.parentActive) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(20)
                .fontColor([AppTheme.PRIMARY]);
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 64 })
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.parentActive ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
          .border({ width: 1, color: this.parentActive ? AppTheme.PRIMARY : AppTheme.BORDER })
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .accessibilityGroup(true)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(this.parentActive ? '家长，当前身份' : '家长，点击切换')
          .onClick(() => this.chooseParent());

          Text('学生')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUBTEXT)
            .margin({ top: 4 });

          ForEach(this.students, (student: StudentProfile) => {
            Row({ space: 12 }) {
              CenteredTextBadge({
                badgeText: student.name.length > 0 ? student.name.substring(0, 1) : '伴',
                badgeWidth: 42,
                badgeHeight: 42,
                badgeFontSize: 16,
                badgeRadius: 14,
                badgeBold: true,
                badgeForeground: !this.parentActive && this.activeStudentId === student.id ?
                  AppTheme.TEXT_ON_PRIMARY : AppTheme.PRIMARY,
                badgeBackground: !this.parentActive && this.activeStudentId === student.id ?
                  AppTheme.PRIMARY : AppTheme.PRIMARY_SOFT
              });
              Column({ space: 3 }) {
                Text(student.name)
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text(student.grade + ' · ' + student.className)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              if (!this.parentActive && this.activeStudentId === student.id) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(20)
                  .fontColor([AppTheme.PRIMARY]);
              }
            }
            .width('100%')
            .constraintSize({ minHeight: 64 })
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(!this.parentActive && this.activeStudentId === student.id ?
              AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
            .border({ width: 1,
              color: !this.parentActive && this.activeStudentId === student.id ?
                AppTheme.PRIMARY : AppTheme.BORDER })
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .accessibilityGroup(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(!this.parentActive && this.activeStudentId === student.id ?
              student.name + '，当前学生身份' : student.name + '，点击切换为学生身份')
            .onClick(() => this.chooseStudent(student.id));
          }, (student: StudentProfile) => student.id);
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4, bottom: 20 });
      }
      .width('100%')
      .constraintSize({ maxHeight: 500 })
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .constraintSize({ maxWidth: 500 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(24);
  }
}
