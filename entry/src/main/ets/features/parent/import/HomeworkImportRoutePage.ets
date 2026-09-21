import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { HomeworkImportPage } from './HomeworkImportPage';

@Component
export struct HomeworkImportRoutePage {
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onStoreChanged: () => void = () => {};

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '手工导入作业',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });

      Row({ space: 10 }) {
        Text('箱')
          .width(28)
          .height(28)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.PRIMARY)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(9);
        Column({ space: 2 }) {
          Text('作业智能收件箱')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('查看手工导入、系统分享和历史整理批次')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%')
      .constraintSize({
        minHeight: AppTheme.MIN_TOUCH_TARGET,
        maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH
      })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('打开作业智能收件箱')
      .onClick(() => this.onOpenInbox());

      Column() {
        HomeworkImportPage({
          revision: this.revision,
          embeddedInDeepPage: true,
          onOpenConfirmation: () => this.onOpenConfirmation(),
          onStoreChanged: () => this.onStoreChanged()
        });
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: AppTheme.PAGE_PADDING,
      right: AppTheme.PAGE_PADDING,
      top: AppTheme.DEEP_PAGE_TOP_PADDING
    })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
