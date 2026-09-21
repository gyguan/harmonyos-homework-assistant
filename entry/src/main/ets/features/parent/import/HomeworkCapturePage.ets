import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { floatView, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { HomeworkCaptureSessionService } from '../../../application/capture/HomeworkCaptureSessionService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { CaptureSession, CaptureSessionStatus } from '../../../domain/model/CaptureModels';

@Component
export struct HomeworkCapturePage {
  onBack: () => void = () => {};
  onOpenInbox: () => void = () => {};

  @State private revision: number = 0;
  @State private message: string = '点击开始后，系统会提示屏幕采集授权。进入班级群后只需手工上滑。';
  @State private errorText: string = '';
  @State private currentSessionId: string = '';
  private floatViewController: floatView.FloatViewController | undefined = undefined;
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    this.refreshTimer = setInterval(() => {
      void this.refreshSession();
    }, 1200);
    void this.refreshSession();
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private session(): CaptureSession | null {
    let currentRevision = this.revision;
    if (currentRevision < 0) return null;
    let active = HomeworkCaptureSessionService.instance.getActiveSession();
    if (active !== null) return active;
    if (this.currentSessionId.length === 0) return null;
    return HomeworkCaptureSessionService.instance.getSession(this.currentSessionId);
  }

  private isRunning(session: CaptureSession | null): boolean {
    if (session === null) return false;
    return session.status === CaptureSessionStatus.CREATED ||
      session.status === CaptureSessionStatus.WAITING_PERMISSION ||
      session.status === CaptureSessionStatus.CAPTURING ||
      session.status === CaptureSessionStatus.STOPPING;
  }

  private async refreshSession(): Promise<void> {
    let active = await HomeworkCaptureSessionService.instance.sampleLatestFrame();
    if (active !== null) {
      this.currentSessionId = active.id;
      if (active.status === CaptureSessionStatus.CAPTURING) {
        this.message = '采集中：请切到目标微信群，手工向上滑动；完成后在悬浮窗点“停止采集”。';
      }
      this.revision++;
      return;
    }

    if (this.currentSessionId.length > 0) {
      let finished = HomeworkCaptureSessionService.instance.getSession(this.currentSessionId);
      if (finished !== null) {
        if (finished.status === CaptureSessionStatus.COMPLETED) {
          this.message = `采集已完成，已生成导入批次；共接受 ${finished.acceptedFrameCount} 个变化画面。`;
          await this.stopFloatView();
        } else if (finished.status === CaptureSessionStatus.CANCELLED) {
          this.message = '本次采集已取消，可以重新开始。';
          await this.stopFloatView();
        } else if (finished.status === CaptureSessionStatus.FAILED) {
          this.message = '本次采集异常结束，资源已释放，可以重新开始。';
          await this.stopFloatView();
        }
      }
    }
    this.revision++;
  }

  private async requestFloatPermission(): Promise<boolean> {
    let hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      this.errorText = '无法获取应用上下文';
      return false;
    }
    try {
      let manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      let result = await manager.requestPermissionsFromUser(
        hostContext, ['ohos.permission.FLOAT_VIEW'] as Permissions[]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.errorText = '未开启悬浮采集状态。请授权后重试。';
        return false;
      }
      return true;
    } catch {
      this.errorText = '悬浮状态授权失败，请稍后重试。';
      return false;
    }
  }

  private registerFloatState(): void {
    this.floatViewController?.onStateChange((info: floatView.FloatViewStateChangeInfo) => {
      if (info.state === floatView.FloatViewState.STOPPED) {
        this.floatViewController?.offStateChange();
        this.floatViewController = undefined;
      }
    });
  }

  private async startFloatView(): Promise<boolean> {
    let granted = await this.requestFloatPermission();
    if (!granted) return false;
    if (!floatView.isFloatViewEnabled()) {
      this.errorText = '当前系统不支持悬浮采集状态';
      return false;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let config: floatView.FloatViewConfiguration = {
        context: context,
        templateType: floatView.FloatViewTemplateType.ROUNDED_RECTANGLE
      };
      this.floatViewController = await floatView.create(config);
      this.registerFloatState();
      await this.floatViewController.setUIContext('pages/HomeworkCaptureFloatView');
      let limits = floatView.getFloatViewLimits(floatView.FloatViewTemplateType.ROUNDED_RECTANGLE);
      let size: window.Size = {
        width: limits.minSize.width,
        height: limits.minSize.height
      };
      await this.floatViewController.setWindowSize(size);
      await this.floatViewController.start();
      return true;
    } catch (error) {
      let businessError = error as BusinessError;
      this.errorText = `悬浮状态启动失败（${businessError.code}）`;
      this.floatViewController = undefined;
      return false;
    }
  }

  private async stopFloatView(): Promise<void> {
    let controller = this.floatViewController;
    this.floatViewController = undefined;
    if (!controller) return;
    try {
      controller.offStateChange();
      await controller.stop();
    } catch {
      // The system/user may already have stopped the FloatView.
    }
  }

  private async startCapture(): Promise<void> {
    this.errorText = '';
    if (HomeworkCaptureSessionService.instance.getActiveSession() !== null) {
      this.errorText = '已有采集任务正在进行，请先结束当前采集。';
      return;
    }
    if (!await this.startFloatView()) return;

    try {
      let studentId = DefaultFamilyContextRepository.instance.getActiveStudentId();
      let session = HomeworkCaptureSessionService.instance.start(studentId);
      this.currentSessionId = session.id;
      this.revision++;
      if (session.status === CaptureSessionStatus.CANCELLED) {
        this.message = '系统未开始屏幕采集，可以重新点击开始。';
        await this.stopFloatView();
        return;
      }
      this.message = '等待系统屏幕采集授权。授权后进入目标微信群并手工上滑。';
    } catch (error) {
      this.errorText = `${error}`;
      await this.stopFloatView();
    }
  }

  private async stopCapture(): Promise<void> {
    let result = await HomeworkCaptureSessionService.instance.stopByUser();
    this.revision++;
    await this.stopFloatView();
    if (result === null) {
      this.message = '当前没有正在进行的采集。';
      return;
    }
    this.currentSessionId = result.id;
    if (result.importBatchId.length > 0) {
      this.message = `采集已结束，已生成导入批次。采集到 ${result.acceptedFrameCount} 个变化画面。`;
    } else {
      this.message = '采集已结束，没有生成导入批次。';
    }
  }

  private async cancelCapture(): Promise<void> {
    let cancelled = await HomeworkCaptureSessionService.instance.cancel();
    if (cancelled !== null) this.currentSessionId = cancelled.id;
    this.revision++;
    await this.stopFloatView();
    this.message = '已取消本次采集，可以重新开始。';
  }

  private back(): void {
    if (this.isRunning(this.session())) {
      this.errorText = '采集中，请先停止或取消本次采集。';
      return;
    }
    this.onBack();
  }

  private statusLabel(status: CaptureSessionStatus): string {
    if (status === CaptureSessionStatus.WAITING_PERMISSION) return '等待系统授权';
    if (status === CaptureSessionStatus.CAPTURING) return '正在采集';
    if (status === CaptureSessionStatus.STOPPING) return '正在结束';
    if (status === CaptureSessionStatus.COMPLETED) return '已完成';
    if (status === CaptureSessionStatus.CANCELLED) return '已取消';
    if (status === CaptureSessionStatus.FAILED) return '采集异常';
    return '准备中';
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '抓取今日作业',
        subtitle: '你手工浏览班级群，小伴只采集当前屏幕',
        backAccessibilityText: '返回导入老师作业',
        onBack: () => this.back()
      });

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('怎么使用')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('1. 点击开始并同意系统屏幕采集授权\n2. 切到目标微信群\n3. 手工向上滑动聊天记录\n4. 到合适位置后在悬浮状态中点“停止采集”')
              .width('100%')
              .fontSize(13)
              .lineHeight(21)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          if (this.session() !== null) {
            Column({ space: 8 }) {
              Row() {
                Text(this.statusLabel(this.session()!.status))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.PRIMARY);
                Blank();
                Text(`变化帧 ${this.session()!.acceptedFrameCount}`)
                  .fontSize(12)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .width('100%');
              Text(`视频回调 ${this.session()!.frameCount} · 最近序号 ${this.session()!.lastFrameSequence}`)
                .width('100%')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.PRIMARY_FAINT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          Text(this.message)
            .width('100%')
            .fontSize(13)
            .lineHeight(19)
            .fontColor(AppTheme.SUBTEXT)
            .padding(12)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          if (!this.isRunning(this.session())) {
            Button('开始抓取今日作业', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.startCapture(); });
          } else {
            Button('停止采集并生成导入批次', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.stopCapture(); });

            Button('取消本次采集', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .fontColor(AppTheme.DANGER)
              .onClick(() => { void this.cancelCapture(); });
          }

          Button('查看作业智能收件箱', { type: ButtonType.Normal })
            .width('100%')
            .enabled(!this.isRunning(this.session()))
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => this.onOpenInbox());

          Text('隐私边界：不会读取微信数据库，不会自动点击或滚动微信，不使用 Accessibility 驱动微信；本阶段只生成屏幕 OCR 证据批次，聊天重建和作业判断由后续能力处理。')
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor(AppTheme.TERTIARY_TEXT)
            .padding({ bottom: 16 });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
        .padding({ top: 4, bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.PAGE_PADDING,
      right: AppTheme.PAGE_PADDING,
      top: AppTheme.DEEP_PAGE_TOP_PADDING
    })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
