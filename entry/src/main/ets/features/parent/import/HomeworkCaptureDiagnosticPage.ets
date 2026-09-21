import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { floatView, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { CaptureFrame, CaptureRuntimeStats } from '../../../domain/model/CaptureModels';
import {
  HomeworkCaptureOcrLine,
  HomeworkCaptureOcrResult,
  HomeworkCaptureOcrService
} from '../../../infrastructure/capture/HomeworkCaptureOcrService';
import { NativeHomeworkCaptureRuntime } from '../../../infrastructure/capture/NativeHomeworkCaptureRuntime';

@Component
export struct HomeworkCaptureDiagnosticPage {
  onBack: () => void = () => {};

  @State private message: string = '点击开始诊断，检查抓取老师作业所需的系统能力。';
  @State private captureStatus: string = '待检测';
  @State private captureDetail: string = '尚未检查屏幕采集能力';
  @State private ocrStatus: string = '待检测';
  @State private ocrDetail: string = '尚未检查文字识别能力';
  @State private floatStatus: string = '待检测';
  @State private floatDetail: string = '尚未检查悬浮状态能力';
  @State private statsText: string = '暂无采集统计';
  @State private frameText: string = '暂无画面信息';
  @State private recognizedText: string = '';
  @State private ocrLines: HomeworkCaptureOcrLine[] = [];
  @State private running: boolean = false;
  @State private analyzing: boolean = false;
  @State private diagnosisStarted: boolean = false;
  @State private diagnosisComplete: boolean = false;
  @State private showAdvanced: boolean = false;

  private refreshTimer: number = -1;
  private floatViewController: floatView.FloatViewController | undefined = undefined;
  private readonly ocrService: HomeworkCaptureOcrService = new HomeworkCaptureOcrService();
  private readonly captureRuntime: NativeHomeworkCaptureRuntime = NativeHomeworkCaptureRuntime.instance;

  aboutToAppear(): void {
    this.refreshTimer = setInterval(() => {
      void this.refreshDiagnosisProgress();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
    this.captureRuntime.stopCapture();
    void this.stopFloatView();
    void this.ocrService.release();
  }

  private overallTitle(): string {
    if (this.analyzing) return '正在生成诊断结果';
    if (this.running) return '正在诊断';
    if (!this.diagnosisStarted) return '尚未诊断';
    if (this.captureStatus === '异常' || this.ocrStatus === '异常' || this.floatStatus === '异常') {
      return '检测到问题';
    }
    if (this.captureStatus === '正常' && this.ocrStatus === '正常' && this.floatStatus === '正常') {
      return '当前环境可正常使用';
    }
    return '诊断未完成';
  }

  private overallDetail(): string {
    if (this.analyzing) return '正在读取最后一个采集画面并检查文字识别。';
    if (this.running) return '请打开一个有文字的页面短暂浏览，然后通过悬浮窗停止，或返回此页结束诊断。';
    if (!this.diagnosisStarted) return '诊断不会创建作业，只检查屏幕采集、文字识别和悬浮状态。';
    if (this.captureStatus === '异常' || this.ocrStatus === '异常' || this.floatStatus === '异常') {
      return '请查看下方异常项；需要进一步排查时可展开高级诊断信息。';
    }
    if (this.diagnosisComplete) return '屏幕采集、文字识别和悬浮状态均已通过检查。';
    return this.message;
  }

  private async requestFloatViewPermission(): Promise<boolean> {
    let hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      this.floatStatus = '异常';
      this.floatDetail = '无法获取应用上下文';
      return false;
    }
    try {
      let manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      let result = await manager.requestPermissionsFromUser(
        hostContext, ['ohos.permission.FLOAT_VIEW'] as Permissions[]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.floatStatus = '异常';
        this.floatDetail = '未获得悬浮窗权限';
        return false;
      }
      return true;
    } catch {
      this.floatStatus = '异常';
      this.floatDetail = '悬浮窗权限申请失败';
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
      let limits = floatView.getFloatViewLimits(floatView.FloatViewTemplateType.ROUNDED_RECTANGLE);
      let size: window.Size = { width: limits.minSize.width, height: limits.minSize.height };
      await this.floatViewController.setWindowSize(size);
      await this.floatViewController.start();
      this.floatStatus = '正常';
      this.floatDetail = '可以显示抓取状态并从悬浮窗停止采集';
      return true;
    } catch (error) {
      let businessError = error as BusinessError;
      this.floatStatus = '异常';
      this.floatDetail = `悬浮状态启动失败（${businessError.code}）`;
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

  private updateStats(): CaptureRuntimeStats {
    let stats = this.captureRuntime.getStats();
    this.statsText =
      `callbacks=${stats.callbackCount} · sampled=${stats.sampledFrameCount} · ` +
      `state=${stats.state} · lastError=${stats.lastError}`;
    if (stats.lastError !== 0) {
      this.captureStatus = '异常';
      this.captureDetail = `屏幕采集返回错误码 ${stats.lastError}`;
    } else if (stats.sampledFrameCount > 0) {
      this.captureStatus = '正常';
      this.captureDetail = `已获取 ${stats.sampledFrameCount} 个有效采样画面`;
    }
    return stats;
  }

  private async refreshDiagnosisProgress(): Promise<void> {
    if (!this.diagnosisStarted || this.analyzing || this.diagnosisComplete) return;
    let wasRunning = this.running;
    let stats = this.updateStats();
    this.running = stats.isCapturing;
    if (wasRunning && !stats.isCapturing &&
      (stats.sampledFrameCount > 0 || stats.lastError !== 0)) {
      await this.analyzeLatestFrame();
    }
  }

  private async startDiagnosis(): Promise<void> {
    if (this.analyzing || this.running) return;
    this.diagnosisStarted = true;
    this.diagnosisComplete = false;
    this.showAdvanced = false;
    this.captureStatus = '检测中';
    this.captureDetail = '等待系统屏幕采集授权和画面';
    this.ocrStatus = '待检测';
    this.ocrDetail = '取得画面后自动检查文字识别';
    this.floatStatus = '检测中';
    this.floatDetail = '正在申请悬浮状态权限';
    this.statsText = '暂无采集统计';
    this.frameText = '暂无画面信息';
    this.recognizedText = '';
    this.ocrLines = [];
    this.captureRuntime.clearLatestFrame();

    let floatReady = await this.startFloatView();
    if (!floatReady) {
      this.message = '悬浮状态不可用，仍可继续检查屏幕采集；返回此页后点击“结束并生成诊断结果”。';
    }

    let result = this.captureRuntime.startCapture();
    let stats = this.updateStats();
    if (result !== 0) {
      this.captureStatus = '异常';
      this.captureDetail = `屏幕采集无法启动（错误码 ${result}）`;
      this.running = false;
      this.diagnosisComplete = true;
      await this.stopFloatView();
      return;
    }

    this.running = stats.isCapturing || result === 0;
    this.captureStatus = '检测中';
    this.captureDetail = '等待系统授权并获取屏幕画面';
    this.message = '授权后请打开一个有文字的页面短暂浏览。可在悬浮窗停止，或返回此页点击结束诊断。';
  }

  private async finishDiagnosis(): Promise<void> {
    if (!this.running || this.analyzing) return;
    this.captureRuntime.stopCapture();
    this.running = false;
    await this.analyzeLatestFrame();
  }

  private async analyzeLatestFrame(): Promise<void> {
    if (this.analyzing || this.diagnosisComplete) return;
    this.analyzing = true;
    await this.stopFloatView();

    let stats = this.updateStats();
    if (stats.sampledFrameCount === 0 && stats.lastError === 0) {
      this.captureStatus = '异常';
      this.captureDetail = '未获取到可用于诊断的屏幕画面';
    }

    let frame: CaptureFrame | undefined = this.captureRuntime.getLatestFrame();
    if (!frame) {
      this.frameText = '没有取得可识别的视频帧';
      this.ocrStatus = '异常';
      this.ocrDetail = '没有可用于文字识别的屏幕画面';
      this.message = '未取得屏幕画面，请检查系统屏幕采集授权后重试。';
      this.analyzing = false;
      this.diagnosisComplete = true;
      return;
    }

    this.frameText =
      `${frame.width}×${frame.height} · sequence=${frame.sequence} · timestamp=${frame.timestamp}`;
    this.ocrStatus = '检测中';
    this.ocrDetail = '正在识别屏幕中的文字';

    try {
      let result: HomeworkCaptureOcrResult = await this.ocrService.recognize(frame);
      this.recognizedText = result.text;
      this.ocrLines = result.lines;
      if (result.text.length > 0 && result.lineCount > 0) {
        this.ocrStatus = '正常';
        this.ocrDetail = `已识别 ${result.lineCount} 行文字`;
        this.message = '诊断完成。';
      } else {
        this.ocrStatus = '异常';
        this.ocrDetail = '文字识别已运行，但没有识别到文字';
        this.message = '请换到文字更清晰的页面后重新诊断。';
      }
    } catch {
      this.ocrStatus = '异常';
      this.ocrDetail = '文字识别执行失败';
      this.message = '文字识别异常，需要进一步排查。';
    } finally {
      this.analyzing = false;
      this.diagnosisComplete = true;
    }
  }

  @Builder
  private DiagnosticRow(label: string, status: string, detail: string) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(detail).fontSize(12).lineHeight(17).fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text(status)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(status === '异常' ? AppTheme.DANGER :
          (status === '正常' ? AppTheme.SUCCESS :
            (status === '检测中' ? AppTheme.WARNING : AppTheme.SUBTEXT)));
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 });
  }

  @Builder
  private AdvancedDiagnostics() {
    Column({ space: 10 }) {
      Text('采集统计').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(this.statsText).width('100%').fontSize(11).lineHeight(17).fontColor(AppTheme.SUBTEXT);
      Text('最后画面').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(this.frameText).width('100%').fontSize(11).lineHeight(17).fontColor(AppTheme.SUBTEXT);

      if (this.recognizedText.length > 0) {
        Text('OCR 全文').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(this.recognizedText).width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
      }

      if (this.ocrLines.length > 0) {
        Text('OCR 行坐标').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        ForEach(this.ocrLines, (line: HomeworkCaptureOcrLine) => {
          Text(`${line.value}  [${line.left},${line.top}]→[${line.right},${line.bottom}]`)
            .width('100%').fontSize(10).lineHeight(16).fontColor(AppTheme.TERTIARY_TEXT);
        }, (line: HomeworkCaptureOcrLine, index: number) =>
          `${index}:${line.left}:${line.top}:${line.value}`);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '屏幕采集诊断',
        subtitle: '检查抓取老师作业所需的系统能力',
        backAccessibilityText: '返回抓取老师作业',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text(this.overallTitle())
              .width('100%')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.overallTitle() === '检测到问题' ? AppTheme.DANGER :
                (this.overallTitle() === '当前环境可正常使用' ? AppTheme.SUCCESS : AppTheme.TEXT));
            Text(this.overallDetail()).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CARD_RADIUS);

          Column({ space: 0 }) {
            this.DiagnosticRow('屏幕采集', this.captureStatus, this.captureDetail);
            Divider().color(AppTheme.DIVIDER);
            this.DiagnosticRow('文字识别', this.ocrStatus, this.ocrDetail);
            Divider().color(AppTheme.DIVIDER);
            this.DiagnosticRow('悬浮状态', this.floatStatus, this.floatDetail);
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Button(this.analyzing ? '正在生成诊断结果…' :
            (this.running ? '结束并生成诊断结果' :
              (this.diagnosisComplete ? '重新诊断' : '开始诊断')), { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .enabled(!this.analyzing)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => {
              if (this.running) {
                void this.finishDiagnosis();
              } else {
                void this.startDiagnosis();
              }
            });

          Row() {
            Text('高级诊断信息').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Blank();
            Text(this.showAdvanced ? '收起' : '展开').fontSize(12).fontColor(AppTheme.PRIMARY);
          }
          .width('100%')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 14, right: 14 })
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(this.showAdvanced ? '收起高级诊断信息' : '展开高级诊断信息')
          .onClick(() => this.showAdvanced = !this.showAdvanced);

          if (this.showAdvanced) this.AdvancedDiagnostics();

          Text('隐私说明：诊断只在内存中使用最新屏幕画面，不落盘、不录音、不读取微信数据库、不自动点击或滚动微信。')
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor(AppTheme.TERTIARY_TEXT)
            .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.CAPTURE_HOME_READABLE_MAX_WIDTH })
        .padding({ top: 4 });
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
