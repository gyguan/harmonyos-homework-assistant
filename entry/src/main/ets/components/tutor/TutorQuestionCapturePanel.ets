import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind } from '../action/ActionControls';
import { TutorQuestionCaptureResult, TutorQuestionCaptureService } from '../../application/tutor/TutorQuestionCaptureService';

@Component
export struct TutorQuestionCapturePanel {
  @Prop studentId: string;
  @State private capturing: boolean = false;
  @State private imageUri: string = '';
  @State private notice: string = '';
  onRecognized: (text: string) => void = () => {};

  private async capture(): Promise<void> {
    if (this.capturing) return;
    let hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.notice = '当前无法打开相机，请稍后重试';
      return;
    }

    this.capturing = true;
    this.notice = '正在打开相机…';
    try {
      let result: TutorQuestionCaptureResult = await TutorQuestionCaptureService.instance.capture(
        hostContext as common.UIAbilityContext, this.studentId);
      if (!result.captured) {
        this.notice = '没有拍摄题目，可以继续文字提问';
        return;
      }
      this.imageUri = result.imageUri;
      this.onRecognized(result.recognizedText);
      this.notice = '题目已在本机识别，请检查文字后再发送';
    } catch (error) {
      let message = error instanceof Error ? error.message : '题目识别失败';
      if (message.indexOf('初始化失败') >= 0) {
        this.notice = '本机文字识别暂不可用，可先使用文字提问';
      } else if (message.indexOf('无法打开系统相机') >= 0) {
        this.notice = '无法打开系统相机，请稍后重试';
      } else if (message.indexOf('无法准备拍题缓存') >= 0 || message.indexOf('无法读取') >= 0) {
        this.notice = '照片读取失败，请重新拍题';
      } else {
        this.notice = `${message}，请重新拍题或改用文字提问`;
      }
    } finally {
      this.capturing = false;
    }
  }

  build() {
    Row({ space: 8 }) {
      ActionButton({
        label: this.capturing ? '识别中…' : '拍题',
        kind: ActionButtonKind.SECONDARY,
        compact: true,
        isEnabled: !this.capturing,
        onAction: (): void => { void this.capture(); }
      });

      if (this.imageUri.length > 0) {
        Image(this.imageUri)
          .width(36)
          .height(36)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS);
      }

      Text(this.notice.length > 0 ? this.notice : '只在本机识别')
        .layoutWeight(1)
        .maxLines(2)
        .fontSize(11)
        .lineHeight(16)
        .fontColor(this.imageUri.length > 0 ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }
}
