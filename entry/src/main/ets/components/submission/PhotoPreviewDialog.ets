import { AppTheme } from '../../common/theme/AppTheme';

@CustomDialog
export struct PhotoPreviewDialog {
  controller: CustomDialogController;
  @Link uri: string;

  build() {
    Column() {
      Row() {
        Text('查看图片')
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White);
        Blank();
        Text('关闭')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭图片全屏预览')
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 });

      if (this.uri.length > 0) {
        Image(this.uri)
          .width('100%')
          .layoutWeight(1)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.Black);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black);
  }
}
