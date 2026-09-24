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
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .maxLines(AppTheme.NAV_TITLE_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .maxLines(AppTheme.META_MAX_LINES)
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('关闭')
        .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
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
