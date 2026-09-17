import { AppTheme } from '../../common/theme/AppTheme';

export enum PrimaryNavPlacement {
  BOTTOM = 'BOTTOM',
  SIDE = 'SIDE'
}

@Component
export struct PrimaryNavItem {
  @Prop symbol: Resource;
  @Prop label: string;
  @Prop selected: boolean = false;
  @Prop placement: PrimaryNavPlacement = PrimaryNavPlacement.BOTTOM;
  onSelect: () => void = () => {};

  @Builder
  private BottomContent() {
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
        .fontSize(11)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private SideContent() {
    Column({ space: 5 }) {
      SymbolGlyph(this.symbol)
        .fontSize(23)
        .fontColor([this.selected ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT]);
      Text(this.label)
        .fontSize(11)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .width(68)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : Color.Transparent)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      if (this.placement === PrimaryNavPlacement.BOTTOM) {
        this.BottomContent();
      } else {
        this.SideContent();
      }
    }
    .width(this.placement === PrimaryNavPlacement.BOTTOM ? '100%' : 68)
    .height(this.placement === PrimaryNavPlacement.BOTTOM ? '100%' : 58)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.selected ? `${this.label}，当前页面` : this.label)
    .onClick(() => this.onSelect());
  }
}
