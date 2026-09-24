import { AppTheme } from '../../common/theme/AppTheme';

@CustomDialog
export struct PracticeSubmitConfirmDialog {
  controller: CustomDialogController;
  @Link unansweredCount: number;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 18 }) {
      Text('还有未作答题目')
        .width('100%')
        .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(`还有 ${this.unansweredCount} 题没有作答。可以继续完成，也可以直接交卷，未答题会按错误计入结果。`)
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 10 }) {
        Button('继续作答', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => this.controller.close());
        Button('仍然交卷', { type: ButtonType.Normal })
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
