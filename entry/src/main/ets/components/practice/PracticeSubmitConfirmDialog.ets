import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind } from '../action/ActionControls';

@CustomDialog
export struct PracticeSubmitConfirmDialog {
  controller: CustomDialogController;
  @Link unansweredCount: number;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 18 }) {
      Text('还有未作答题目')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(`还有 ${this.unansweredCount} 题没有作答。可以继续完成，也可以直接交卷，未答题会按错误计入结果。`)
        .width('100%')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 10 }) {
        ActionButton({
          label: '继续作答',
          kind: ActionButtonKind.NEUTRAL,
          onClick: () => this.controller.close()
        })
        .layoutWeight(1);
        ActionButton({
          label: '仍然交卷',
          onClick: () => {
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
