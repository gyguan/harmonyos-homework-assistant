import { AppTheme } from '../common/theme/AppTheme';

@Entry
@Component
struct HomeworkShareReceivingPage {
  build() {
    Column({ space: 12 }) {
      Text('小伴作业')
        .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
        .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text('正在接收分享内容…')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      Text('图片会先安全复制到小伴本地，再进入作业整理。')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.SURFACE);
  }
}
