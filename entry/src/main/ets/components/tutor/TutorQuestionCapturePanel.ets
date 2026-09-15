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
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Button(this.capturing ? '识别中…' : '拍题问小伴', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.capturing)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.capture(); });
        if (this.imageUri.length > 0) {
          Image(this.imageUri)
            .width(54)
            .height(54)
            .objectFit(ImageFit.Cover)
            .borderRadius(10)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS);
        }
      }
      .width('100%');

      Text('题目图片只在本机识别；发送给小伴的是你检查、修改后的识别文字。')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(18)
        .fontColor(AppTheme.SUBTEXT);

      if (this.notice.length > 0) {
        Text(this.notice)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(this.imageUri.length > 0 ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
