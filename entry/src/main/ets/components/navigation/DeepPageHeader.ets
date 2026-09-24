import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct DeepPageHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop trailingText: string = '';
  @Prop backAccessibilityText: string = '返回上一页';
  onBack: () => void = () => {};

  build() {
    Row({ space: AppTheme.DEEP_PAGE_HEADER_GAP }) {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(AppTheme.DEEP_PAGE_BACK_GLYPH_SIZE)
          .fontColor([AppTheme.TEXT]);
      }
      .width(AppTheme.MIN_TOUCH_TARGET)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.MIN_TOUCH_TARGET / 2)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.backAccessibilityText)
      .onClick(() => this.onBack());

      Column({ space: 1 }) {
        Text(this.title)
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(AppTheme.DEEP_PAGE_HEADER_META_SIZE)
            .fontColor(AppTheme.SUBTEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      if (this.trailingText.length > 0) {
        Text(this.trailingText)
          .fontSize(AppTheme.DEEP_PAGE_HEADER_META_SIZE)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .width('100%')
    .height(AppTheme.DEEP_PAGE_HEADER_HEIGHT)
    .alignItems(VerticalAlign.Center);
  }
}
