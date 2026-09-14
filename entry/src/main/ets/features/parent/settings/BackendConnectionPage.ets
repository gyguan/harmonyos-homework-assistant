import { AppTheme } from '../../../common/theme/AppTheme';
import { BackendAuthService } from '../../../application/remote/BackendAuthService';
import { BackendSession } from '../../../application/remote/BackendSession';
import { HomeworkSyncService } from '../../../application/remote/HomeworkSyncService';

@Component
export struct BackendConnectionPage {
  @State private baseUrl: string = '';
  @State private loginName: string = 'parent';
  @State private password: string = '';
  @State private message: string = '';
  @State private connecting: boolean = false;
  onStoreChanged: () => void = () => {};

  private async connect(): Promise<void> {
    if (this.baseUrl.trim().length === 0 || this.loginName.trim().length === 0 || this.password.length === 0) {
      this.message = '请填写服务地址、账号和密码'; return;
    }
    this.connecting = true; this.message = '正在连接…';
    try {
      let displayName = await BackendAuthService.instance.login(this.baseUrl, this.loginName, this.password);
      let synced = await HomeworkSyncService.instance.syncActiveStudent();
      this.message = synced ? `已连接：${displayName}，当前孩子数据已同步` : `已登录：${displayName}，同步暂时失败`;
      this.onStoreChanged();
    } catch {
      this.message = '连接失败，请检查电脑局域网地址、后端服务和账号密码';
    } finally { this.connecting = false; }
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('云端连接').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('只同步已确认发布的作业和提交，不上传老师原文解析中间态。').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%').alignItems(HorizontalAlign.Start);

        Column({ space: 12 }) {
          TextInput({ placeholder: '例如 http://192.168.1.10:8080', text: this.baseUrl })
            .width('100%').height(AppTheme.INPUT_HEIGHT).onChange((value: string) => this.baseUrl = value);
          TextInput({ placeholder: '家长账号', text: this.loginName })
            .width('100%').height(AppTheme.INPUT_HEIGHT).onChange((value: string) => this.loginName = value);
          TextInput({ placeholder: '密码', text: this.password })
            .width('100%').height(AppTheme.INPUT_HEIGHT).type(InputType.Password)
            .onChange((value: string) => this.password = value);
          Button(this.connecting ? '正在连接…' : '连接并同步', { type: ButtonType.Normal })
            .width('100%').height(AppTheme.BUTTON_HEIGHT).borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.connecting).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.connect(); });
          if (this.message.length > 0) Text(this.message).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
          Text(BackendSession.instance.isConnected() ? '状态：已连接' : '状态：未连接')
            .width('100%').fontSize(13).fontColor(BackendSession.instance.isConnected() ? AppTheme.SUCCESS : AppTheme.TERTIARY_TEXT);
        }
        .width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);
      }.width('100%').padding(AppTheme.PAGE_PADDING);
    }.width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
