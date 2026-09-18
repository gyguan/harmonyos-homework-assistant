import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../common/theme/AppTheme';
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
    } catch {
      this.notice = '题目识别失败，请拍清楚一些再试';
    } finally {
      this.capturing = false;
    }
  }

  build() {
    Row({ space: 8 }) {
      Button(this.capturing ? '识别中…' : '拍题问小伴', { type: ButtonType.Normal })
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.capturing)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => { void this.capture(); });

      if (this.imageUri.length > 0) {
        Image(this.imageUri)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS);
      }

      Text(this.notice.length > 0 ? this.notice : '只在本机识别 · 识别后可编辑')
        .layoutWeight(1)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(18)
        .fontColor(this.imageUri.length > 0 ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }
}
