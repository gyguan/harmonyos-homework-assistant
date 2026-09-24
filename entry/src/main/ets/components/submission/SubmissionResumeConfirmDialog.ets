import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, TextAction } from '../action/ActionControls';

@CustomDialog
export struct SubmissionResumeConfirmDialog {
  controller: CustomDialogController;
  @Link photoCount: number;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 18 }) {
      Row() {
        Text('继续完成作业')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          accessibilityLabel: '取消继续作业',
          onAction: (): void => this.controller.close()
        });
      }
      .width('100%');

      Text(`继续作业会清空尚未提交的 ${this.photoCount} 张照片，需要重新选择或拍摄。`)
        .width('100%')
        .fontSize(15)
        .lineHeight(23)
        .fontColor(AppTheme.SUBTEXT);

      Row({ space: 10 }) {
        ActionButton({
          label: '先不继续',
          kind: ActionButtonKind.NEUTRAL,
          onAction: (): void => this.controller.close()
        })
        .layoutWeight(1);
        ActionButton({
          label: '清空并继续',
          onAction: (): void => {
            this.controller.close();
            this.onConfirm();
          }
        })
        .layoutWeight(1);
      }
      .width('100%');
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .padding(22)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(22);
  }
}
