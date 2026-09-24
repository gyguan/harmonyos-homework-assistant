import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct BottomPrimaryNavItem {
  @Prop symbol: Resource;
  @Prop label: string;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Column({ space: 3 }) {
      Row() {
        SymbolGlyph(this.symbol)
          .fontSize(22)
          .fontColor([this.selected ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT]);
      }
      .width(40)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(AppTheme.CHIP_RADIUS);
      Text(this.label)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.selected ? `${this.label}，当前页面` : this.label)
    .onClick(() => this.onSelect());
  }
}

@Component
export struct SidePrimaryNavItem {
  @Prop symbol: Resource;
  @Prop label: string;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Column({ space: 5 }) {
      SymbolGlyph(this.symbol)
        .fontSize(23)
        .fontColor([this.selected ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT]);
      Text(this.label)
        .fontSize(AppTheme.META_SIZE)
        .lineHeight(AppTheme.META_LINE_HEIGHT)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .width(72)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : Color.Transparent)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.selected ? `${this.label}，当前页面` : this.label)
    .onClick(() => this.onSelect());
  }
}
