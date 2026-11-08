import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../../common/theme/AppTheme';

/** 全屏层展示的媒体快照（整体克隆替换，避免嵌套对象观察不到变更）。 */
export class VoiceFullscreenMedia {
  open: boolean = false;
  imageUris: string[] = [];
  imageIndex: number = 0;
  playing: boolean = false;
  currentTimeMs: number = 0;
  durationMs: number = 0;
  playbackEnabled: boolean = false;
  prepared: boolean = false;

  clone(): VoiceFullscreenMedia {
    let copy: VoiceFullscreenMedia = new VoiceFullscreenMedia();
    copy.open = this.open;
    copy.imageUris = this.imageUris.slice();
    copy.imageIndex = this.imageIndex;
    copy.playing = this.playing;
    copy.currentTimeMs = this.currentTimeMs;
    copy.durationMs = this.durationMs;
    copy.playbackEnabled = this.playbackEnabled;
    copy.prepared = this.prepared;
    return copy;
  }
}

/**
 * 语音作业全屏层的全局桥。
 *
 * 全屏必须盖住侧边导航、NavDestination 标题栏和底部操作条——这些都在
 * StudyWorkspacePage 的祖先层级里，页面内部的 Stack overlay 永远做不到。
 * 因此展示状态上收到 AppShell 根 Stack 挂载的 VoiceFullscreenLayer：
 * 页面只负责把播放器的媒体状态与控制函数桥接进来，全屏层本身不持有播放器。
 */
export class VoiceFullscreenHub {
  static readonly instance: VoiceFullscreenHub = new VoiceFullscreenHub();
  private static readonly REVISION_KEY: string = 'voiceFullscreenRevision';

  private media: VoiceFullscreenMedia = new VoiceFullscreenMedia();
  private revision: number = 0;

  // 由 StudyWorkspacePage 在 aboutToAppear 里接线到仍然挂载的 VoiceAssignmentPane。
  toggleAudio: () => void = () => {};
  seek: (value: number) => void = (_value: number) => {};
  previousImage: () => void = () => {};
  nextImage: () => void = () => {};
  selectImage: (index: number) => void = (_index: number) => {};

  snapshot(): VoiceFullscreenMedia {
    return this.media.clone();
  }

  isOpen(): boolean {
    return this.media.open;
  }

  open(current: VoiceFullscreenMedia): void {
    let next = current.clone();
    next.open = true;
    this.media = next;
    this.publish();
  }

  /** 全屏打开时同步播放进度 / 图片索引等媒体状态；未打开时只缓存不广播。 */
  update(current: VoiceFullscreenMedia): void {
    if (!this.media.open) {
      this.media = current.clone();
      return;
    }
    let next = current.clone();
    next.open = true;
    this.media = next;
    this.publish();
  }

  close(): void {
    if (!this.media.open) return;
    let next = this.media.clone();
    next.open = false;
    this.media = next;
    this.publish();
  }

  /** 系统返回键在全屏打开时只退出全屏；true 表示本次返回已被消费。 */
  requestCloseIfOpen(): boolean {
    if (!this.media.open) return false;
    this.close();
    return true;
  }

  /** 宿主页面销毁时清桥，防止全屏层继续调用已卸载页面里的播放器。 */
  resetControls(): void {
    this.toggleAudio = () => {};
    this.seek = (_value: number) => {};
    this.previousImage = () => {};
    this.nextImage = () => {};
    this.selectImage = (_index: number) => {};
  }

  private publish(): void {
    this.revision += 1;
    AppStorage.setOrCreate<number>(VoiceFullscreenHub.REVISION_KEY, this.revision);
  }
}

/**
 * 窗口级全屏层：挂在 AppShell 根 Stack，覆盖整个应用窗口（含侧边导航与
 * NavDestination 标题栏），打开期间隐藏系统状态栏 / 导航条实现真全屏。
 */
@Component
export struct VoiceFullscreenLayer {
  @StorageProp('voiceFullscreenRevision') @Watch('onRevisionChanged') revision: number = -1;
  @State private layerOpen: boolean = false;
  @State private imageUris: string[] = [];
  @State private imageIndex: number = 0;
  @State private playing: boolean = false;
  @State private currentTimeMs: number = 0;
  @State private durationMs: number = 0;
  @State private playbackEnabled: boolean = false;
  @State private prepared: boolean = false;

  aboutToAppear(): void {
    this.onRevisionChanged();
  }

  aboutToDisappear(): void {
    void this.applyImmersive(false);
  }

  private onRevisionChanged(): void {
    let snapshot: VoiceFullscreenMedia = VoiceFullscreenHub.instance.snapshot();
    this.layerOpen = snapshot.open;
    this.imageUris = snapshot.imageUris;
    this.imageIndex = snapshot.imageIndex;
    this.playing = snapshot.playing;
    this.currentTimeMs = snapshot.currentTimeMs;
    this.durationMs = snapshot.durationMs;
    this.playbackEnabled = snapshot.playbackEnabled;
    this.prepared = snapshot.prepared;
    void this.applyImmersive(snapshot.open);
  }

  /** 全屏期间隐藏系统栏；失败只影响沉浸效果，不阻断全屏展示。 */
  private async applyImmersive(immersive: boolean): Promise<void> {
    try {
      let hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) return;
      let win = await window.getLastWindow(hostContext as common.UIAbilityContext);
      if (immersive) {
        await win.setWindowLayoutFullScreen(true);
        await win.setWindowSystemBarEnable([]);
      } else {
        await win.setWindowSystemBarEnable(['status', 'navigation']);
        await win.setWindowLayoutFullScreen(false);
      }
    } catch (error) {
      // 沉浸式失败时全屏层仍然覆盖应用窗口内容区。
    }
  }

  private formatVoiceTime(ms: number): string {
    let totalSeconds = Math.max(0, Math.floor(ms / 1000));
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.layerOpen) {
        this.FullscreenBody();
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .hitTestBehavior(this.layerOpen ? HitTestMode.Default : HitTestMode.None);
  }

  @Builder
  private FullscreenBody() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(`${this.imageIndex + 1} / ${this.imageUris.length}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF');
        Blank();
        Button('关闭', { type: ButtonType.Normal })
          .width(72)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#3A3A3A')
          .borderRadius(20)
          .accessibilityText('退出全屏')
          .onClick(() => VoiceFullscreenHub.instance.close());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      this.FullscreenImage();
      this.FullscreenThumbnails();
      this.FullscreenAudio();
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#111111');
  }

  @Builder
  private FullscreenImage() {
    Stack({ alignContent: Alignment.Center }) {
      Swiper() {
        ForEach(this.imageUris, (uri: string, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (uri.length > 0) {
              Image(uri)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain);
            } else {
              LoadingProgress()
                .width(32)
                .height(32)
                .color(AppTheme.PRIMARY);
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#111111');
        }, (uri: string, index: number) => `${index}-${uri}`);
      }
      .width('100%')
      .height('100%')
      .index(this.imageIndex)
      .indicator(false)
      .loop(true)
      .onChange((index: number) => {
        this.imageIndex = index;
        VoiceFullscreenHub.instance.selectImage(index);
      });

      if (this.imageUris.length > 1) {
        Row() {
          Button('←', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#E6FFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('上一张情景图片')
            .onClick(() => VoiceFullscreenHub.instance.previousImage());
          Blank();
          Button('→', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#E6FFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('下一张情景图片')
            .onClick(() => VoiceFullscreenHub.instance.nextImage());
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12 });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  private FullscreenThumbnails() {
    if (this.imageUris.length > 1) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.imageUris, (uri: string, index: number) => {
            Stack({ alignContent: Alignment.Center }) {
              if (uri.length > 0) {
                Image(uri)
                  .width(68)
                  .height(56)
                  .objectFit(ImageFit.Cover);
              } else {
                Text(`${index + 1}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#D8D8D8');
              }
            }
            .width(68)
            .height(56)
            .border({
              width: index === this.imageIndex ? 2 : 1,
              color: index === this.imageIndex ? AppTheme.PRIMARY : '#666666'
            })
            .borderRadius(10)
            .backgroundColor('#242424')
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(`查看第 ${index + 1} 张情景图片`)
            .onClick(() => VoiceFullscreenHub.instance.selectImage(index));
          }, (uri: string, index: number) => `${index}-${uri}`);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
  }

  @Builder
  private FullscreenAudio() {
    Row({ space: 12 }) {
      Button(this.playing ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
        .width(52)
        .height(52)
        .fontSize(this.playing ? 19 : 17)
        .enabled(this.playbackEnabled && this.prepared)
        .backgroundColor(this.playbackEnabled && this.prepared ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .accessibilityText(this.playing ? '暂停语音' : '播放语音')
        .onClick(() => VoiceFullscreenHub.instance.toggleAudio());

      Column({ space: 2 }) {
        Slider({
          value: this.currentTimeMs,
          min: 0,
          max: this.durationMs > 0 ? this.durationMs : 1,
          step: 1000,
          style: SliderStyle.InSet
        })
          .width('100%')
          .selectedColor(AppTheme.PRIMARY)
          .trackColor('#4A4A4A')
          .enabled(this.playbackEnabled && this.prepared)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.currentTimeMs = value;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              VoiceFullscreenHub.instance.seek(value);
            }
          });

        Row() {
          Text(this.formatVoiceTime(this.currentTimeMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor('#D8D8D8');
          Blank();
          Text(this.formatVoiceTime(this.durationMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor('#D8D8D8');
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding({ top: 8, bottom: 4 });
  }
}
