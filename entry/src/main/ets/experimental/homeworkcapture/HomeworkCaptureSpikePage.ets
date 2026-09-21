import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { floatView, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import nativeCapture, { CapturedFrame, CaptureStats } from 'libhomeworkcapture.so';
import { AppTheme } from '../../common/theme/AppTheme';
import { DeepPageHeader } from '../../components/navigation/DeepPageHeader';
import { DefaultFamilyContextRepository } from '../../data/repository/DefaultFamilyContextRepository';
import { Issue244CaptureSessionFixture } from './Issue244CaptureSessionFixture';
import { Issue245ChatReconstructionFixture } from './Issue245ChatReconstructionFixture';
import { Issue246HomeworkUnderstandingFixture } from './Issue246HomeworkUnderstandingFixture';
import { Issue247FullClosureFixture } from './Issue247FullClosureFixture';
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
  @State private issue244FixtureStatus: string = 'PENDING';
  @State private issue245FixtureStatus: string = 'PENDING';
  @State private issue246FixtureStatus: string = 'PENDING';
  @State private issue247FixtureStatus: string = 'PENDING';

  private floatViewController: floatView.FloatViewController | undefined = undefined;
  private readonly ocrService: HomeworkCaptureOcrService = new HomeworkCaptureOcrService();

  aboutToDisappear(): void {
    nativeCapture.stopCapture();
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

  private registerFloatState(): void {
    this.floatViewController?.onStateChange((info: floatView.FloatViewStateChangeInfo) => {
      if (info.state === floatView.FloatViewState.STOPPED) {
        this.floatViewController?.offStateChange();
        this.floatViewController = undefined;
      }
    });
  }

  private async startFloatView(): Promise<boolean> {
    let granted = await this.requestFloatViewPermission();
    if (!granted) return false;
    if (!floatView.isFloatViewEnabled()) {
      this.floatStatus = 'FAIL · 系统悬浮视图不可用';
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
      controller.offStateChange();
      await controller.stop();
    } catch {
      // A user may already have closed the system-managed float view.
    }
  }

  private updateStats(): CaptureStats {
    let stats: CaptureStats = nativeCapture.getStats();
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
    nativeCapture.clearLatestFrame();

    let floatReady = await this.startFloatView();
    if (!floatReady) {
      this.message = 'FloatView 未启动；仍可继续验证屏幕采集，但需通过系统方式停止后再返回小伴。';
    }

    let result = nativeCapture.startCapture();
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
    let result = nativeCapture.stopCapture();
    this.updateStats();
    this.running = false;
    this.message = result === 0
      ? '已从小伴停止采集。注意：若刚从微信返回，最后一帧可能已经是小伴界面。'
      : `停止采集返回错误码 ${result}`;
  }

  private async runIssue244Fixture(): Promise<void> {
    if (this.running) {
      this.issue244FixtureStatus = 'FAIL · 请先停止 #241 真机采集';
      return;
    }
    this.issue244FixtureStatus = 'RUNNING';
    try {
      let result = await Issue244CaptureSessionFixture.run(
        DefaultFamilyContextRepository.instance.getActiveStudentId());
      this.issue244FixtureStatus = result.passed ?
        `PASS · 3 sampled → ${result.acceptedFrameCount} accepted → ${result.messageCount} messages → 1 batch` :
        'FAIL · Fixture 结果不满足 #244 Gate';
    } catch (error) {
      this.issue244FixtureStatus = `FAIL · ${error}`;
    }
  }

  private runIssue245Fixture(): void {
    if (this.running) {
      this.issue245FixtureStatus = 'FAIL · 请先停止 #241 真机采集';
      return;
    }
    this.issue245FixtureStatus = 'RUNNING';
    try {
      let result = Issue245ChatReconstructionFixture.run();
      this.issue245FixtureStatus = result.passed ?
        `PASS · 5 frames → ${result.messageCount} unique · A证据=${result.repeatedMessageEvidenceCount} · boundary=${result.earliestDetectedTime}` :
        'FAIL · #245 Fixture 结果不满足重建 Gate';
    } catch (error) {
      this.issue245FixtureStatus = `FAIL · ${error}`;
    }
  }

  private runIssue246Fixture(): void {
    if (this.running) {
      this.issue246FixtureStatus = 'FAIL · 请先停止 #241 真机采集';
      return;
    }
    this.issue246FixtureStatus = 'RUNNING';
    try {
      let result = Issue246HomeworkUnderstandingFixture.run();
      let accuracy = Math.round(result.classificationAccuracy * 100);
      this.issue246FixtureStatus = result.passed ?
        `PASS · ${result.caseCount} cases · classification=${accuracy}% · grouping=${result.groupingPassed}/${result.groupingTotal} · revision=${result.revisionPassed}/${result.revisionTotal} · extraction=${result.taskExtractionPassed}/${result.taskExtractionTotal}` :
        `FAIL · classification=${accuracy}% · grouping=${result.groupingPassed}/${result.groupingTotal} · revision=${result.revisionPassed}/${result.revisionTotal} · extraction=${result.taskExtractionPassed}/${result.taskExtractionTotal}`;
    } catch (error) {
      this.issue246FixtureStatus = `FAIL · ${error}`;
    }
  }

  private runIssue247Fixture(): void {
    if (this.running) {
      this.issue247FixtureStatus = 'FAIL · 请先停止 #241 真机采集';
      return;
    }
    this.issue247FixtureStatus = 'RUNNING';
    try {
      let result = Issue247FullClosureFixture.run();
      this.issue247FixtureStatus = result.passed ?
        `PASS · group=matched · boundary=${result.earliestDetectedTime} · messages=${result.uniqueMessageCount}→${result.inWindowMessageCount} · 32→33 · homework+preparation` :
        'FAIL · #247 全闭环 Fixture 未满足目标';
    } catch (error) {
      this.issue247FixtureStatus = `FAIL · ${error}`;
    }
  }

  private async readAndRecognize(): Promise<void> {
    let stats = this.updateStats();
    if (stats.isCapturing) {
      this.message = '采集仍在进行。请先在悬浮视图停止；否则返回小伴后会覆盖微信最后一帧。';
      return;
    }
    await this.stopFloatView();

    let frame: CapturedFrame | undefined = nativeCapture.getLatestFrame();
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

          Column({ space: 8 }) {
            Text('#244 业务流程 Fixture')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('不调用真实录屏：验证 Session 状态机、Frame Diff、OCR Stub 与“一 Session 一 ImportBatch”。')
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(AppTheme.SUBTEXT);
            Text(this.issue244FixtureStatus)
              .width('100%')
              .fontSize(12)
              .fontColor(this.issue244FixtureStatus.startsWith('FAIL') ? AppTheme.DANGER :
                (this.issue244FixtureStatus.startsWith('PASS') ? AppTheme.SUCCESS : AppTheme.SUBTEXT));
            Button('运行 #244 离线流程自测', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.running)
              .onClick(() => { void this.runIssue244Fixture(); });
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Column({ space: 8 }) {
            Text('#245 聊天重建 Fixture')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('5 个 50% 重叠 Frame：验证顺序重建、重复消息合并、时间边界、缺时间、图片与 OCR 失败容错。')
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(AppTheme.SUBTEXT);
            Text(this.issue245FixtureStatus)
              .width('100%')
              .fontSize(12)
              .fontColor(this.issue245FixtureStatus.startsWith('FAIL') ? AppTheme.DANGER :
                (this.issue245FixtureStatus.startsWith('PASS') ? AppTheme.SUCCESS : AppTheme.SUBTEXT));
            Button('运行 #245 聊天重建自测', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.running)
              .onClick(() => this.runIssue245Fixture());
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Column({ space: 8 }) {
            Text('#246 作业理解 Fixture')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('20 组固定用例：老师/别名、六类分类、多消息合并、更正覆盖、删除、准备、通知与 UNKNOWN。')
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(AppTheme.SUBTEXT);
            Text(this.issue246FixtureStatus)
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(this.issue246FixtureStatus.startsWith('FAIL') ? AppTheme.DANGER :
                (this.issue246FixtureStatus.startsWith('PASS') ? AppTheme.SUCCESS : AppTheme.SUBTEXT));
            Button('运行 #246 作业理解自测', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.running)
              .onClick(() => this.runIssue246Fixture());
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          Column({ space: 8 }) {
            Text('#247 一键抓取完整闭环 Fixture')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('模拟二(3)班群：验证 15:00 边界、群名、家长聊天过滤、32→33、更正、两项作业与明日准备。')
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(AppTheme.SUBTEXT);
            Text(this.issue247FixtureStatus)
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(this.issue247FixtureStatus.startsWith('FAIL') ? AppTheme.DANGER :
                (this.issue247FixtureStatus.startsWith('PASS') ? AppTheme.SUCCESS : AppTheme.SUBTEXT));
            Button('运行 #247 完整闭环自测', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.running)
              .onClick(() => this.runIssue247Fixture());
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
