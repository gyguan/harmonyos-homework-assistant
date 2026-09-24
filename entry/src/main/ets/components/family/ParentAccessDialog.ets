import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, TextAction, TextActionKind } from '../action/ActionControls';

@CustomDialog
export struct ParentAccessDialog {
  controller: CustomDialogController;
  @Link code: string;
  @Link message: string;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 3 }) {
          Text('验证家长身份')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('请输入设备家长码')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭家长身份验证',
          onAction: (): void => this.controller.close()
        });
      }
      .width('100%');

      TextInput({ placeholder: '4 位数字家长码', text: this.code })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .type(InputType.Password)
        .maxLength(4)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.code = value;
          this.message = '';
        });

      if (this.message.length > 0) {
        Text(this.message)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.DANGER);
      }

      ActionButton({
        label: '进入家长模式',
        onAction: (): void => this.onConfirm()
      })
      .width('100%');
    }
    .width('100%')
    .constraintSize({ maxWidth: 420 })
    .padding(22)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(22);
  }
}
