import { AppTheme } from '../../common/theme/AppTheme';
import { CenteredTextBadge } from './CenteredTextBadge';
import { StudentProfile } from '../../domain/model/HomeworkModels';

@CustomDialog
export struct StudentSwitcherDialog {
  controller: CustomDialogController;
  @Link students: StudentProfile[];
  @Link activeStudentId: string;
  onSelect: (studentId: string) => void = (_studentId: string) => {};

  private choose(studentId: string): void {
    this.onSelect(studentId);
    this.controller.close();
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('选择孩子')
            .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
            .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .maxLines(AppTheme.NAV_TITLE_MAX_LINES)
            .fontColor(AppTheme.TEXT);
          Text('切换后首页、进度和作业都会同步到该孩子')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT)
            .maxLines(2);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text('关闭')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭孩子选择')
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.students, (student: StudentProfile) => {
            Row({ space: 12 }) {
              CenteredTextBadge({
                badgeText: student.name.length > 0 ? student.name.substring(0, 1) : '伴',
                badgeWidth: 42,
                badgeHeight: 42,
                badgeFontSize: 16,
                badgeRadius: 14,
                badgeForeground: this.activeStudentId === student.id ? AppTheme.TEXT_ON_PRIMARY : AppTheme.PRIMARY,
                badgeBackground: this.activeStudentId === student.id ? AppTheme.PRIMARY : AppTheme.PRIMARY_SOFT
              });
              Column({ space: 3 }) {
                Text(student.name)
                  .width('100%')
                  .fontSize(AppTheme.CARD_TITLE_SIZE)
                  .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
                  .fontColor(AppTheme.TEXT);
                Text(`${student.grade} · ${student.className}`)
                  .width('100%')
                  .fontSize(AppTheme.CAPTION_SIZE)
                  .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                  .fontColor(AppTheme.SUBTEXT)
                  .maxLines(2);
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              if (this.activeStudentId === student.id) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(20)
                  .fontColor([AppTheme.PRIMARY]);
              }
            }
            .width('100%')
            .constraintSize({ minHeight: 64 })
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(AppTheme.CARD_SURFACE)
            .border({ width: 1,
              color: this.activeStudentId === student.id ? AppTheme.PRIMARY : AppTheme.BORDER })
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .accessibilityGroup(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.activeStudentId === student.id ?
              `${student.name}，${student.grade}，${student.className}，当前孩子` :
              `${student.name}，${student.grade}，${student.className}，点击切换`)
            .onClick(() => this.choose(student.id));
          }, (student: StudentProfile) => student.id);
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4, bottom: 20 });
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .constraintSize({ maxWidth: 480 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(24);
  }
}
