import { AppTheme } from '../../common/theme/AppTheme';
import { TextAction } from '../action/ActionControls';

@CustomDialog
export struct PhotoPreviewDialog {
  controller: CustomDialogController;
  @Link uri: string;

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('查看作业照片')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          accessibilityLabel: '关闭照片预览',
          onAction: () => this.controller.close()
        });
      }
      .width('100%');

      if (this.uri.length > 0) {
        Image(this.uri)
          .width('100%')
          .layoutWeight(1)
          .objectFit(ImageFit.Contain)
          .backgroundColor(AppTheme.BACKGROUND);
      }
    }
    .width('92%')
    .height('78%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(20);
  }
}
