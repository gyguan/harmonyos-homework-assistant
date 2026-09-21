import { HomeworkCaptureSessionService } from '../application/capture/HomeworkCaptureSessionService';
import { AppTheme } from '../common/theme/AppTheme';
import { CaptureSessionStatus } from '../domain/model/CaptureModels';
import nativeCapture, { CaptureStats } from 'libhomeworkcapture.so';

@Entry
@Component
struct HomeworkCaptureFloatView {
  @State private statusText: string = '作业采集中';
  @State private detailText: string = '在班级群中手工上滑；到目标位置后点停止';
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    this.refreshTimer = setInterval(() => {
      void this.refreshFormalSession();
    }, 1200);
    void this.refreshFormalSession();
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private async refreshFormalSession(): Promise<void> {
    let active = HomeworkCaptureSessionService.instance.getActiveSession();
    if (active === null) return;
    let session = await HomeworkCaptureSessionService.instance.sampleLatestFrame();
    if (session === null) return;

    if (session.status === CaptureSessionStatus.WAITING_PERMISSION) {
      this.statusText = '等待系统授权';
      this.detailText = '同意屏幕采集后，再进入班级群手工上滑';
    } else if (session.status === CaptureSessionStatus.CAPTURING) {
      this.statusText = '作业采集中';
      this.detailText = `变化帧 ${session.acceptedFrameCount} · 到目标位置后点停止`;
    } else if (session.status === CaptureSessionStatus.STOPPING) {
      this.statusText = '正在结束采集';
      this.detailText = '正在整理本次屏幕证据';
    } else if (session.status === CaptureSessionStatus.COMPLETED) {
      this.statusText = '采集已完成';
      this.detailText = `已收集 ${session.acceptedFrameCount} 个变化画面，请返回小伴查看导入批次`;
    } else if (session.status === CaptureSessionStatus.CANCELLED) {
      this.statusText = '采集已取消';
      this.detailText = '请返回小伴重新开始';
    } else if (session.status === CaptureSessionStatus.FAILED) {
      this.statusText = '采集异常结束';
      this.detailText = '资源已释放，请返回小伴查看状态';
    }
  }

  private async stopCapture(): Promise<void> {
    let active = HomeworkCaptureSessionService.instance.getActiveSession();
    if (active !== null) {
      let result = await HomeworkCaptureSessionService.instance.stopByUser();
      if (result !== null && result.importBatchId.length > 0) {
        this.statusText = '采集已完成';
        this.detailText = `已收集 ${result.acceptedFrameCount} 个变化画面，请返回小伴查看导入批次`;
      } else {
        this.statusText = '采集已停止';
        this.detailText = '没有生成导入批次，可以返回小伴重新开始';
      }
      return;
    }

    // Compatibility fallback for the isolated #241 feasibility spike.
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
        .onClick(() => { void this.stopCapture(); });
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE);
  }
}
