import { AppTheme } from '../common/theme/AppTheme';
import nativeCapture, { CaptureStats } from 'libhomeworkcapture.so';

@Entry
@Component
struct HomeworkCaptureFloatView {
  @State private statusText: string = '作业采集中';
  @State private detailText: string = '在班级群中手工上滑；到目标位置后点停止';

  private stopCapture(): void {
    let code = nativeCapture.stopCapture();
    let stats: CaptureStats = nativeCapture.getStats();
    if (code === 0) {
      this.statusText = '采集已停止';
      this.detailText = `已收到 ${stats.callbackCount} 个视频回调，请返回小伴读取 OCR 结果`;
    } else {
      this.statusText = '停止请求异常';
      this.detailText = `错误码 ${code}，请返回小伴结束实验`;
    }
  }

  build() {
    Column({ space: 8 }) {
      Text(this.statusText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .width('100%');
      Text(this.detailText)
        .fontSize(11)
        .lineHeight(16)
        .fontColor(AppTheme.SUBTEXT)
        .maxLines(2)
        .width('100%');
      Button('停止采集', { type: ButtonType.Normal })
        .width('100%')
        .height(36)
        .borderRadius(10)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.stopCapture());
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE);
  }
}
