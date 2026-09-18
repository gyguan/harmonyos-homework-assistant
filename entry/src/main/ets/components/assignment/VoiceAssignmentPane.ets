import { AppTheme } from '../../common/theme/AppTheme';
import { RemoteAssignmentResourceApi } from '../../application/remote/RemoteAssignmentResourceApi';
import {
  AssignmentResource,
  AssignmentResourceType
} from '../../domain/model/HomeworkModels';
import {
  AssignmentAudioPlayerCallbacks,
  AssignmentAudioPlayerService
} from '../../application/assignment/AssignmentAudioPlayerService';

@Component
export struct VoiceAssignmentPane {
  @Prop assignmentId: string = '';
  @Prop playbackEnabled: boolean = false;
  @State private loading: boolean = true;
  @State private message: string = '';
  @State private imageUris: string[] = [];
  @State private imageIndex: number = 0;
  @State private audioUri: string = '';
  @State private prepared: boolean = false;
  @State private playing: boolean = false;
  @State private currentTimeMs: number = 0;
  @State private durationMs: number = 0;

  onPauseReady: (pause: () => void) => void = (_pause: () => void) => {};
  private readonly player: AssignmentAudioPlayerService = new AssignmentAudioPlayerService();

  aboutToAppear(): void {
    this.onPauseReady(() => { void this.pauseAudio(); });
    void this.load();
  }

  aboutToDisappear(): void {
    this.onPauseReady(() => {});
    void this.player.release();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      let resources = await RemoteAssignmentResourceApi.instance.list(this.assignmentId);
      let audio: AssignmentResource | null = null;
      let images: AssignmentResource[] = [];
      for (let resource of resources) {
        if (resource.resourceType === AssignmentResourceType.AUDIO && audio === null) audio = resource;
        if (resource.resourceType === AssignmentResourceType.IMAGE) images.push(resource);
      }
      if (audio === null || images.length === 0) {
        this.message = '语音作业资料不完整，请让家长重新发布';
        return;
      }

      let audioUri = await RemoteAssignmentResourceApi.instance.download(audio);
      if (audioUri.length === 0) {
        this.message = '语音加载失败，请检查网络后重试';
        return;
      }

      let downloadedImages: string[] = [];
      for (let image of images) {
        let uri = await RemoteAssignmentResourceApi.instance.download(image);
        if (uri.length > 0) downloadedImages.push(uri);
      }
      if (downloadedImages.length === 0) {
        this.message = '情景图片加载失败，请检查网络后重试';
        return;
      }

      this.audioUri = audioUri;
      this.imageUris = downloadedImages;
      this.imageIndex = 0;

      let callbacks: AssignmentAudioPlayerCallbacks = {
        onPrepared: (durationMs: number) => {
          this.prepared = true;
          this.durationMs = durationMs;
          this.currentTimeMs = 0;
        },
        onState: (state) => {
          this.playing = state === 'playing';
          if (state === 'completed') this.playing = false;
        },
        onTime: (timeMs: number) => {
          this.currentTimeMs = timeMs;
        },
        onError: (_message: string) => {
          this.playing = false;
          this.message = '语音播放暂时不可用，请稍后重试';
        }
      };
      await this.player.prepare(this.audioUri, callbacks);
    } catch {
      this.message = '作业资料加载失败，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private async toggleAudio(): Promise<void> {
    if (!this.playbackEnabled || !this.prepared) return;
    if (this.playing) await this.pauseAudio();
    else await this.player.play();
  }

  private async pauseAudio(): Promise<void> {
    if (!this.playing) return;
    await this.player.pause();
  }

  private selectImage(index: number): void {
    if (index < 0 || index >= this.imageUris.length || index === this.imageIndex) return;
    this.imageIndex = index;
  }

  private formatTime(ms: number): string {
    let totalSeconds = Math.max(0, Math.floor(ms / 1000));
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  @Builder
  private ImageViewer() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(this.imageUris[this.imageIndex])
          .width('100%')
          .height(286)
          .objectFit(ImageFit.Contain)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS);

        Text(`${this.imageIndex + 1} / ${this.imageUris.length}`)
          .margin({ top: 10, right: 10 })
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .backgroundColor('#66000000')
          .borderRadius(12);
      }
      .width('100%');

      if (this.imageUris.length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.imageUris, (uri: string, index: number) => {
              Image(uri)
                .width(64)
                .height(54)
                .objectFit(ImageFit.Cover)
                .border({
                  width: index === this.imageIndex ? 2 : 1,
                  color: index === this.imageIndex ? AppTheme.PRIMARY : AppTheme.BORDER
                })
                .borderRadius(10)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText(`查看第 ${index + 1} 张情景图片`)
                .onClick(() => this.selectImage(index));
            }, (uri: string, index: number) => `${index}-${uri}`);
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
    }
    .width('100%');
  }

  @Builder
  private AudioControls() {
    Column({ space: 5 }) {
      Row({ space: 10 }) {
        Button(this.playing ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
          .width(48)
          .height(48)
          .fontSize(this.playing ? 18 : 16)
          .enabled(this.playbackEnabled && this.prepared)
          .backgroundColor(this.playbackEnabled && this.prepared ? AppTheme.PRIMARY : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .accessibilityText(this.playing ? '暂停语音' : '播放语音')
          .onClick(() => { void this.toggleAudio(); });

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
            .trackColor(AppTheme.PRIMARY_SOFT)
            .enabled(this.playbackEnabled && this.prepared)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.currentTimeMs = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.player.seek(value);
              }
            });

          Row() {
            Text(this.formatTime(this.currentTimeMs)).fontSize(10).fontColor(AppTheme.SUBTEXT);
            Blank();
            Text(this.formatTime(this.durationMs)).fontSize(10).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      if (!this.playbackEnabled) {
        Text('开始或继续作业后可播放语音')
          .width('100%')
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column({ space: 10 }) {
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color(AppTheme.PRIMARY);
          Text('正在加载语音和情景图片…').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (this.message.length > 0) {
        Column({ space: 8 }) {
          Text(this.message).fontSize(12).lineHeight(18).fontColor(AppTheme.WARNING);
          Text('重新加载')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.load(); });
        }
        .width('100%')
        .padding(14)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(AppTheme.WARNING_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (this.imageUris.length > 0 && this.audioUri.length > 0) {
        Column({ space: 10 }) {
          this.ImageViewer();
          this.AudioControls();
        }
        .width('100%')
        .padding(10)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      }
    }
    .width('100%');
  }
}
