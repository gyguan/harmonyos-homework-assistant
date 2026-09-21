import { HomeworkCaptureSessionService } from '../application/capture/HomeworkCaptureSessionService';
import { HomeworkCaptureWorkflowService } from '../application/capture/HomeworkCaptureWorkflowService';
import { AppTheme } from '../common/theme/AppTheme';
import { CaptureSessionStatus } from '../domain/model/CaptureModels';
import { SourceGroupValidationStatus } from '../domain/model/HomeworkSourceProfileModels';
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
    let progress = await HomeworkCaptureWorkflowService.instance.progress();
    if (progress === null) return;
    let session = progress.session;

    if (session.status === CaptureSessionStatus.WAITING_PERMISSION) {
      this.statusText = '等待系统授权';
      this.detailText = '同意屏幕采集后，再进入班级群手工上滑';
    } else if (session.status === CaptureSessionStatus.CAPTURING) {
      if (progress.groupValidationStatus === SourceGroupValidationStatus.CONFLICT) {
        this.statusText = '检测到多个微信群';
        this.detailText = '请结束本次采集，并从目标班级群重新开始';
      } else if (progress.groupValidationStatus === SourceGroupValidationStatus.MISMATCH) {
        this.statusText = '当前群与配置不一致';
        this.detailText = `识别到“${progress.detectedGroupTitle}”，请返回正确班级群`;
      } else if (progress.timeBoundaryReached) {
        this.statusText = '已到达今日时间范围';
        this.detailText = `已看到 ${progress.earliestDetectedTime}，现在可以结束并自动整理`;
      } else if (progress.groupValidationStatus === SourceGroupValidationStatus.MATCHED) {
        this.statusText = '班级群已确认';
        this.detailText = `变化帧 ${session.acceptedFrameCount} · 继续手工上滑到今日开始时间`;
      } else {
        this.statusText = '作业采集中';
        this.detailText = `变化帧 ${session.acceptedFrameCount} · 正在识别群名和时间范围`;
      }
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
      let result = await HomeworkCaptureWorkflowService.instance.finishByUser();
      if (result !== null && result.batchId.length > 0) {
        if (!result.reconstructionSucceeded) {
          this.statusText = '采集已完成，聊天重建待处理';
          this.detailText = '原始屏幕证据已保留，请返回小伴查看';
        } else if (result.groupValidationStatus === SourceGroupValidationStatus.CONFLICT) {
          this.statusText = '检测到多个微信群';
          this.detailText = '为避免混入其他群消息，本次不会自动整理';
        } else if (result.groupValidationStatus === SourceGroupValidationStatus.MISMATCH) {
          this.statusText = '群名不一致';
          this.detailText = '本次不会自动整理为作业，请返回小伴查看';
        } else if (result.needsGroupConfirmation) {
          this.statusText = '需要确认群名';
          this.detailText = '群名未可靠识别，请返回小伴确认后继续';
        } else if (!result.understandingSucceeded) {
          this.statusText = '采集已完成，作业理解待处理';
          this.detailText = '聊天消息已保留，请返回小伴稍后重试或人工处理';
        } else if (result.activated) {
          this.statusText = '已整理完成';
          this.detailText = `已整理 ${result.candidateCount} 项，请返回小伴确认发布`;
        } else {
          this.statusText = '采集已完成';
          this.detailText = '结果已保留，请返回小伴查看';
        }
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
