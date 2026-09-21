import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { floatView, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { CaptureSession, CaptureSessionStatus } from '../../../domain/model/CaptureModels';
import { SourceGroupValidationStatus } from '../../../domain/model/HomeworkSourceProfileModels';
import {
  HomeworkCapturePageResult,
  HomeworkCaptureViewModel
} from './HomeworkCaptureViewModel';

@Component
export struct HomeworkCapturePage {
  onBack: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  onOpenSourceProfile: (startCaptureAfterSave: boolean) => void = (_startCaptureAfterSave: boolean) => {};

  @State private revision: number = 0;
  @State private message: string = '点击开始后，系统会提示屏幕采集授权。进入班级群后只需手工上滑。';
  @State private errorText: string = '';
  @State private currentSessionId: string = '';
  @State private detectedGroupTitle: string = '';
  @State private groupValidationStatus: SourceGroupValidationStatus = SourceGroupValidationStatus.UNRECOGNIZED;
  @State private timeBoundaryReached: boolean = false;
  @State private earliestDetectedTime: string = '';
  @State private pendingGroupConfirmationBatchId: string = '';
  private finalizedBatchId: string = '';
  private autoStartAttempted: boolean = false;
  private floatViewController: floatView.FloatViewController | undefined = undefined;
  private refreshTimer: number = -1;
  private readonly viewModel: HomeworkCaptureViewModel = new HomeworkCaptureViewModel();

  aboutToAppear(): void {
    this.refreshTimer = setInterval(() => {
      void this.refreshSession();
    }, 1200);
    void this.initializePage();
  }

  private async initializePage(): Promise<void> {
    await this.refreshSession();
    if (this.autoStartAttempted || this.currentSessionId.length > 0) return;
    this.autoStartAttempted = true;
    if (!this.viewModel.hasActiveProfile()) {
      this.errorText = '尚未配置班级采集设置，请先完成一次配置。';
      return;
    }
    await this.startCapture();
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
    return this.viewModel.activeOrSession(this.currentSessionId);
  }

  private isRunning(session: CaptureSession | null): boolean {
    if (session === null) return false;
    return session.status === CaptureSessionStatus.CREATED ||
      session.status === CaptureSessionStatus.WAITING_PERMISSION ||
      session.status === CaptureSessionStatus.CAPTURING ||
      session.status === CaptureSessionStatus.STOPPING;
  }

  private async refreshSession(): Promise<void> {
    let progress = await this.viewModel.progress();
    if (progress !== null) {
      let active = progress.session;
      this.currentSessionId = active.id;
      this.detectedGroupTitle = progress.detectedGroupTitle;
      this.groupValidationStatus = progress.groupValidationStatus;
      this.timeBoundaryReached = progress.timeBoundaryReached;
      this.earliestDetectedTime = progress.earliestDetectedTime;

      if (active.status === CaptureSessionStatus.CAPTURING) {
        if (progress.groupValidationStatus === SourceGroupValidationStatus.CONFLICT) {
          this.errorText = '本次采集检测到多个不同微信群，已停止自动整理。请结束本次采集，并从目标班级群重新开始。';
        } else if (progress.groupValidationStatus === SourceGroupValidationStatus.MISMATCH) {
          this.errorText = `当前识别群“${progress.detectedGroupTitle}”与配置“${progress.profile.groupTitle}”不一致，请确认已进入正确微信群。`;
        } else if (progress.timeBoundaryReached) {
          this.errorText = '';
          this.message = `已到达今日抓取时间范围（${this.viewModel.formatStartTime(progress.profile)}），可以结束并自动整理。`;
        } else if (progress.groupValidationStatus === SourceGroupValidationStatus.MATCHED) {
          this.errorText = '';
          this.message = `已确认“${progress.profile.groupTitle}”，继续手工上滑；小伴正在读取今天的消息。`;
        } else {
          this.message = '正在识别群标题和聊天消息，请继续手工上滑。';
        }
      }

      if ((active.status === CaptureSessionStatus.COMPLETED || active.status === CaptureSessionStatus.FAILED) &&
        active.importBatchId.length > 0 && this.finalizedBatchId !== active.importBatchId) {
        this.finalizedBatchId = active.importBatchId;
        let result = this.viewModel.finalizeCompletedSession(active.id);
        if (result !== null) await this.handleWorkflowResult(result);
      }
      this.revision++;
      return;
    }

    if (this.currentSessionId.length > 0) {
      let finished = this.viewModel.activeOrSession(this.currentSessionId);
      if (finished !== null) {
        if (finished.status === CaptureSessionStatus.COMPLETED) {
          if (finished.importBatchId.length > 0 && this.finalizedBatchId !== finished.importBatchId) {
            this.finalizedBatchId = finished.importBatchId;
            let result = this.viewModel.finalizeCompletedSession(finished.id);
            if (result !== null) {
              await this.handleWorkflowResult(result);
              this.revision++;
              return;
            }
          }
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

  private async startFloatView(): Promise<boolean> {
    let granted = await this.requestFloatPermission();
    if (!granted) return false;
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let config: floatView.FloatViewConfiguration = {
        context: context,
        templateType: floatView.FloatViewTemplateType.ROUNDED_RECTANGLE
      };
      this.floatViewController = await floatView.create(config);
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
      await controller.stop();
    } catch {
      // The system/user may already have stopped the FloatView.
    }
  }

  private async startCapture(): Promise<void> {
    this.errorText = '';
    if (this.viewModel.hasActiveSession()) {
      this.errorText = '已有采集任务正在进行，请先结束当前采集。';
      return;
    }
    if (!await this.startFloatView()) return;

    try {
      let session = this.viewModel.start();
      this.currentSessionId = session.id;
      this.revision++;
      if (session.status === CaptureSessionStatus.CANCELLED) {
        this.message = '系统未开始屏幕采集，可以重新点击开始。';
        await this.stopFloatView();
        return;
      }
      this.message = '等待系统屏幕采集授权。授权后进入目标微信群并手工上滑。';
    } catch {
      this.errorText = '屏幕采集启动失败，请稍后重试。';
      await this.stopFloatView();
    }
  }

  private async stopCapture(): Promise<void> {
    let result = await this.viewModel.finishByUser();
    this.revision++;
    await this.stopFloatView();
    if (result === null) {
      this.message = '当前没有正在进行的采集，或本次没有生成导入批次。';
      return;
    }
    this.currentSessionId = result.session.id;
    this.finalizedBatchId = result.batchId;
    await this.handleWorkflowResult(result);
  }

  private async handleWorkflowResult(result: HomeworkCapturePageResult): Promise<void> {
    this.detectedGroupTitle = result.detectedGroupTitle;
    this.groupValidationStatus = result.groupValidationStatus;
    this.timeBoundaryReached = result.timeBoundaryReached;
    this.earliestDetectedTime = result.earliestDetectedTime;
    await this.stopFloatView();

    if (!result.reconstructionSucceeded) {
      this.errorText = '聊天重建未完成，原始屏幕证据已经保留在收件箱，可以稍后重试或人工处理。';
      this.message = '本次屏幕采集已经安全结束。';
      return;
    }

    if (result.groupValidationStatus === SourceGroupValidationStatus.CONFLICT) {
      this.errorText = '本次采集混入了多个微信群的内容。原始证据已保留，但不会自动生成作业，请从目标班级群重新抓取。';
      this.message = '为避免把其他群消息混入作业，本次自动整理已阻断。';
      return;
    }

    if (result.groupValidationStatus === SourceGroupValidationStatus.MISMATCH) {
      this.errorText = `识别到群“${result.detectedGroupTitle}”，与班级采集设置不一致。本次不会自动整理为作业，请进入正确群后重新抓取。`;
      this.message = '采集证据已保留在收件箱，未生成待发布作业。';
      return;
    }

    if (result.needsGroupConfirmation) {
      this.pendingGroupConfirmationBatchId = result.batchId;
      this.errorText = '';
      this.message = '没有可靠识别到群标题。请确认当前确实是目标班级群后再继续整理。';
      return;
    }

    this.pendingGroupConfirmationBatchId = '';
    if (!result.understandingSucceeded) {
      this.errorText = '聊天消息已重建并保留，但作业理解未完成。请到收件箱稍后重试或人工处理。';
      this.message = '本次屏幕采集已经安全结束。';
      return;
    }

    this.errorText = '';
    if (result.activated && result.candidateCount > 0) {
      this.message = `已整理出 ${result.candidateCount} 项内容，正在进入家长确认。`;
      this.onOpenConfirmation();
      return;
    }
    if (result.pendingReviewCount > 0) {
      this.message = `已完成整理，其中 ${result.pendingReviewCount} 条消息需要人工确认，请到收件箱处理。`;
      return;
    }
    this.message = result.candidateCount > 0 ?
      `已整理出 ${result.candidateCount} 项内容，可进入收件箱继续确认。` :
      '已完成整理，没有识别到需要发布的作业。';
  }

  private async confirmUnrecognizedGroup(): Promise<void> {
    let batchId = this.pendingGroupConfirmationBatchId;
    if (batchId.length === 0) return;
    let result = this.viewModel.confirmUnrecognizedAndContinue(batchId);
    if (result === null) {
      this.errorText = '无法继续整理本次采集，请到收件箱查看原始消息。';
      return;
    }
    await this.handleWorkflowResult(result);
  }

  private async cancelCapture(): Promise<void> {
    let cancelled = await this.viewModel.cancel();
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
        subtitle: '进群手工上滑，小伴自动识别、整理并交给你确认',
        backAccessibilityText: '返回抓取老师作业',
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
            Text('1. 同意系统屏幕采集授权\n2. 切到配置的班级群\n3. 手工向上滑动聊天记录\n4. 到达默认时间范围后点“结束并整理”')
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
            Row() {
              Text(this.statusLabel(this.session()!.status))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.PRIMARY);
              Blank();
              Text(`已采集 ${this.session()!.acceptedFrameCount} 个有效画面`)
                .fontSize(13)
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
              .fontSize(13)
              .lineHeight(18)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          if (this.pendingGroupConfirmationBatchId.length > 0) {
            Button('确认是目标班级群，继续整理', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.confirmUnrecognizedGroup(); });
          }

          if (!this.isRunning(this.session()) && this.pendingGroupConfirmationBatchId.length === 0) {
            Button('重新开始抓取', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.startCapture(); });
          } else {
            Button(this.timeBoundaryReached ? '已到达时间范围，结束并整理' : '结束采集并自动整理',
              { type: ButtonType.Normal })
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

          Button('修改班级采集设置', { type: ButtonType.Normal })
            .width('100%')
            .enabled(!this.isRunning(this.session()))
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .onClick(() => this.onOpenSourceProfile(false));

          Button('查看作业智能收件箱', { type: ButtonType.Normal })
            .width('100%')
            .enabled(!this.isRunning(this.session()))
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => this.onOpenInbox());

          Text('隐私边界：不会读取微信数据库，不会自动点击或滚动微信，不使用 Accessibility 驱动微信；只处理你主动打开并浏览的当前屏幕，最终作业仍由家长确认发布。')
            .width('100%')
            .fontSize(12)
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
      .align(Alignment.TopStart)
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
