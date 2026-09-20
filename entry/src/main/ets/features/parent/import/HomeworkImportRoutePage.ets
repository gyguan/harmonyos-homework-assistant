import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { HomeworkImportPage } from './HomeworkImportPage';

@Component
export struct HomeworkImportRoutePage {
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  onOpenCaptureSpike: () => void = () => {};
  onStoreChanged: () => void = () => {};

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '导入老师作业',
        subtitle: '老师原文 → 小伴整理 → 家长确认发布',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.viewfinder'))
          .fontSize(18)
          .fontColor([AppTheme.PRIMARY]);
        Column({ space: 2 }) {
          Text('实验：抓取今日作业')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('#241 · 屏幕采集 / OCR / 悬浮状态真机验证')
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('打开作业智能采集可行性实验')
      .onClick(() => this.onOpenCaptureSpike());

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
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: AppTheme.DEEP_PAGE_TOP_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
