import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct CenteredTextBadge {
  @Prop badgeText: string = '';
  @Prop badgeWidth: number = 40;
  @Prop badgeHeight: number = 40;
  @Prop badgeFontSize: number = 15;
  @Prop badgeRadius: number = 12;
  @Prop badgeBold: boolean = false;
  @Prop badgeForeground: ResourceColor = AppTheme.TEXT;
  @Prop badgeBackground: ResourceColor = AppTheme.SURFACE;

  build() {
    Stack() {
      Text(this.badgeText)
        .fontSize(this.badgeFontSize)
        .fontWeight(this.badgeBold ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.badgeForeground);
    }
    .width(this.badgeWidth)
    .height(this.badgeHeight)
    .alignContent(Alignment.Center)
    .backgroundColor(this.badgeBackground)
    .borderRadius(this.badgeRadius);
  }
}
