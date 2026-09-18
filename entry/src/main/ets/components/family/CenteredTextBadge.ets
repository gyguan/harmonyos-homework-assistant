import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct CenteredTextBadge {
  @Prop text: string = '';
  @Prop width: number = 40;
  @Prop height: number = 40;
  @Prop fontSize: number = 15;
  @Prop radius: number = 12;
  @Prop bold: boolean = false;
  @Prop foreground: ResourceColor = AppTheme.TEXT;
  @Prop background: ResourceColor = AppTheme.SURFACE;

  build() {
    Stack() {
      Text(this.text)
        .fontSize(this.fontSize)
        .fontWeight(this.bold ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.foreground);
    }
    .width(this.width)
    .height(this.height)
    .alignContent(Alignment.Center)
    .backgroundColor(this.background)
    .borderRadius(this.radius);
  }
}
