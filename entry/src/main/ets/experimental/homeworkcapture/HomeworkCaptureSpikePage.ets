import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { floatView, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CaptureFrame, CaptureRuntimeStats } from '../../domain/model/CaptureModels';
import { NativeHomeworkCaptureRuntime } from '../../infrastructure/capture/NativeHomeworkCaptureRuntime';
import { AppTheme } from '../../common/theme/AppTheme';
import { DeepPageHeader } from '../../components/navigation/DeepPageHeader';
import {
  HomeworkCaptureOcrLine,
  HomeworkCaptureOcrResult,
  HomeworkCaptureOcrService
} from './HomeworkCaptureOcrService';

@Component
export struct HomeworkCaptureSpikePage {
  onBack: () => void = () => {};
  @State private message: string = '尚未运行真机验证';
  @State private captureStatus: string = 'PENDING';
  @State private ocrStatus: string = 'PENDING';
  @State private floatStatus: string = 'PENDING';
  @State private statsText: string = '暂无采集统计';
  @State private frameText: string = '暂无采集帧';
  @State private recognizedText: string = '';
  @State private ocrLines: HomeworkCaptureOcrLine[] = [];
  @State private running: boolean = false;

  private floatViewController: floatView.FloatViewController | undefined = undefined;
  private readonly ocrService: HomeworkCaptureOcrService = new HomeworkCaptureOcrService();
  private readonly captureRuntime: NativeHomeworkCaptureRuntime = NativeHomeworkCaptureRuntime.instance;

  aboutToDisappear(): void {
    this.captureRuntime.stopCapture();
    void this.stopFloatView();
    void this.ocrService.release();
  }

  private async requestFloatViewPermission(): Promise<boolean> {
    let hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      this.floatStatus = 'FAIL · 无 UIAbilityContext';
      return false;
    }
    try {
      let manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      let result = await manager.requestPermissionsFromUser(
        hostContext, ['ohos.permission.FLOAT_VIEW'] as Permissions[]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.floatStatus = 'FAIL · 用户未授权';
        return false;
      }
      return true;
    } catch {
      this.floatStatus = 'FAIL · 权限申请异常';
      return false;
    }
  }

  private async startFloatView(): Promise<boolean> {
    let granted = await this.requestFloatViewPermission();
    if (!granted) return false;
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let config: floatView.FloatViewConfiguration = {
        context: context,
        templateType: floatView.FloatViewTemplateType.ROUNDED_RECTANGLE
      };
      this.floatViewController = await floatView.create(config);
      await this.floatViewController.setUIContext('pages/HomeworkCaptureFloatView');
      let limits: floatView.FloatViewLimits =
        floatView.getFloatViewLimits(floatView.FloatViewTemplateType.ROUNDED_RECTANGLE);
      let size: window.Size = {
        width: limits.minSize.width,
        height: limits.minSize.height
      };
      await this.floatViewController.setWindowSize(size);
      await this.floatViewController.start();
      this.floatStatus = 'RUNTIME · 已启动，待真机观察覆盖效果';
      return true;
    } catch (error) {
      let businessError = error as BusinessError;
      this.floatStatus = `FAIL · FloatView ${businessError.code}`;
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
      // A user may already have closed the system-managed float view.
    }
  }

  private updateStats(): CaptureRuntimeStats {
    let stats: CaptureRuntimeStats = this.captureRuntime.getStats();
    this.running = stats.isCapturing;
    this.statsText =
      `callbacks=${stats.callbackCount} · sampled=${stats.sampledFrameCount} · ` +
      `state=${stats.state} · lastError=${stats.lastError}`;
    if (stats.sampledFrameCount > 0 && stats.lastError === 0) {
      this.captureStatus = 'RUNTIME · 已收到视频帧';
    } else if (stats.lastError !== 0) {
      this.captureStatus = `FAIL · error=${stats.lastError}`;
    }
    return stats;
  }

  private async startTest(): Promise<void> {
    this.message = '正在准备悬浮状态与系统屏幕采集授权…';
    this.captureStatus = 'PENDING';
    this.ocrStatus = 'PENDING';
    this.recognizedText = '';
    this.ocrLines = [];
    this.captureRuntime.clearLatestFrame();

    let floatReady = await this.startFloatView();
    if (!floatReady) {
      this.message = 'FloatView 未启动；仍可继续验证屏幕采集，但需通过系统方式停止后再返回小伴。';
    }

    let result: number = this.captureRuntime.startCapture();
    this.updateStats();
    if (result !== 0) {
      this.captureStatus = `FAIL · startCapture=${result}`;
      this.message = '屏幕采集启动失败。记录错误码后结束本次 Gate。';
      this.running = false;
      await this.stopFloatView();
      return;
    }

    this.running = true;
    this.captureStatus = 'RUNTIME · 等待系统授权/视频帧';
    this.message =
      '授权后进入微信测试群，手工上滑 3~5 屏并持续约 30 秒。优先在悬浮视图中点“停止采集”，再返回小伴读取结果。';
  }

  private stopCaptureHere(): void {
    let result: number = this.captureRuntime.stopCapture();
    this.updateStats();
    this.running = false;
    this.message = result === 0
      ? '已从小伴停止采集。注意：若刚从微信返回，最后一帧可能已经是小伴界面。'
      : `停止采集返回错误码 ${result}`;
  }

  private async readAndRecognize(): Promise<void> {
    let stats = this.updateStats();
    if (stats.isCapturing) {
      this.message = '采集仍在进行。请先在悬浮视图停止；否则返回小伴后会覆盖微信最后一帧。';
      return;
    }
    await this.stopFloatView();

    let frame: CaptureFrame | undefined = this.captureRuntime.getLatestFrame();
    if (!frame) {
      this.frameText = '没有取得可识别的视频帧';
      this.ocrStatus = 'FAIL · NO_FRAME';
      this.message = '未取得视频帧，请确认系统屏幕采集授权是否成功。';
      return;
    }

    this.frameText =
      `${frame.width}×${frame.height} · sequence=${frame.sequence} · timestamp=${frame.timestamp}`;
    this.message = '正在对内存中的最新 RGBA 帧执行 Core Vision OCR…';
    try {
      let result: HomeworkCaptureOcrResult = await this.ocrService.recognize(frame);
      this.recognizedText = result.text;
      this.ocrLines = result.lines;
      if (result.text.length > 0 && result.lineCount > 0) {
        this.ocrStatus = `RUNTIME · ${result.blockCount} blocks / ${result.lineCount} lines`;
        this.message = 'OCR 已返回文字和行坐标；请按 #241 Fixture 人工确认群标题、时间和正文是否正确。';
      } else {
        this.ocrStatus = 'FAIL · OCR_EMPTY';
        this.message = 'Core Vision 已执行，但没有识别到文字。';
      }
    } catch {
      this.ocrStatus = 'FAIL · OCR_EXCEPTION';
      this.message = 'Core Vision OCR 执行失败，请记录真机日志。';
    }
  }

  @Builder
  private GateRow(label: string, status: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Blank();
      Text(status)
        .fontSize(12)
        .fontColor(status.startsWith('FAIL') ? AppTheme.DANGER :
          (status.startsWith('RUNTIME') ? AppTheme.WARNING : AppTheme.SUBTEXT));
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 });
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '#241 作业智能采集可行性',
        subtitle: '仅验证 AVScreenCapture / OCR / FloatView，不创建作业',
        backAccessibilityText: '返回导入老师作业',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 4 }) {
            Text('真机 Gate')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('这里的 RUNTIME 只表示代码路径有运行证据；最终 PASS 必须按 Issue #241 在真机人工确认。')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Column({ space: 0 }) {
            this.GateRow('AVScreenCapture', this.captureStatus);
            Divider().color(AppTheme.DIVIDER);
            this.GateRow('Core Vision OCR', this.ocrStatus);
            Divider().color(AppTheme.DIVIDER);
            this.GateRow('FloatView', this.floatStatus);
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Column({ space: 8 }) {
            Text('测试 Fixture')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('二(3)班家长群\n17:31 王老师\n今晚语文作业：\n1. 生字词每个写两遍\n2. 朗读第8课三遍')
              .width('100%')
              .fontSize(13)
              .lineHeight(20)
              .fontColor(AppTheme.TEXT)
              .padding(12)
              .backgroundColor(AppTheme.SURFACE_SUBTLE)
              .borderRadius(10);
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Button(this.running ? '采集中…' : '开始真机采集实验', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .enabled(!this.running)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.startTest(); });

          if (this.running) {
            Button('从小伴停止采集', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .fontColor(AppTheme.TEXT)
              .onClick(() => this.stopCaptureHere());
          }

          Button('读取最近一帧并执行 OCR', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.readAndRecognize(); });

          Text(this.message)
            .width('100%')
            .fontSize(13)
            .lineHeight(19)
            .fontColor(AppTheme.SUBTEXT)
            .padding(12)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);

          Column({ space: 6 }) {
            Text('采集统计').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text(this.statsText).fontSize(12).fontColor(AppTheme.SUBTEXT);
            Text(this.frameText).fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          if (this.recognizedText.length > 0) {
            Column({ space: 8 }) {
              Text('OCR 全文')
                .width('100%')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text(this.recognizedText)
                .width('100%')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(AppTheme.TEXT);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          if (this.ocrLines.length > 0) {
            Column({ space: 8 }) {
              Text('OCR 行坐标证据')
                .width('100%')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              ForEach(this.ocrLines, (line: HomeworkCaptureOcrLine) => {
                Text(`${line.value}  [${line.left},${line.top}]→[${line.right},${line.bottom}]`)
                  .width('100%')
                  .fontSize(11)
                  .lineHeight(17)
                  .fontColor(AppTheme.SUBTEXT);
              }, (line: HomeworkCaptureOcrLine, index: number) =>
                `${index}:${line.left}:${line.top}:${line.value}`);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          Text('隐私约束：本实验仅在内存中保留最新一帧；不落盘、不录音、不读取微信数据库、不自动点击或滚动微信。')
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
