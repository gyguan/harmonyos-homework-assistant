import { AppTheme } from '../../common/theme/AppTheme';

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
        Text('关闭')
          .fontSize(13)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 2 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('取消继续作业')
          .onClick(() => this.controller.close());
      }
      .width('100%');

      Text(`继续作业会清空尚未提交的 ${this.photoCount} 张照片，需要重新选择或拍摄。`)
        .width('100%')
        .fontSize(15)
        .lineHeight(23)
        .fontColor(AppTheme.SUBTEXT);

      Row({ space: 10 }) {
        Button('先不继续', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => this.controller.close());
        Button('清空并继续', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => {
            this.controller.close();
            this.onConfirm();
          });
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
