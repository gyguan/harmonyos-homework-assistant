import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct EditSheetHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop closeAccessibilityText: string = '关闭';
  onClose: () => void = () => {};

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .maxLines(1)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('关闭')
        .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
        .fontSize(14)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(this.closeAccessibilityText)
        .onClick(() => this.onClose());
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 });
  }
}
