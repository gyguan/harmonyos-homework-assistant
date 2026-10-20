import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct CloudConnectionReminder {
  onConnect: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000');

      Column({ space: 16 }) {
        Text('尚未连接云服务器')
          .width('100%')
          .fontSize(AppTheme.PAGE_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .textAlign(TextAlign.Center);

        Text('当前可以继续使用本地功能，但家庭成员、跨设备作业同步及云端服务可能不可用。你可以现在连接，也可以稍后再设置。')
          .width('100%')
          .fontSize(AppTheme.BODY_SIZE)
          .lineHeight(AppTheme.BODY_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);

        Button('连接云服务器', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onConnect());

        Button('暂不连接，继续使用本地功能', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.onDismiss());
      }
      .width('90%')
      .constraintSize({ maxWidth: 420 })
      .padding(24)
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CARD_RADIUS);
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center);
  }
}
