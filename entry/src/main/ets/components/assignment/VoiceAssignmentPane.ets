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
  @State private imageLoading: boolean = false;
  @State private imageLoadMessage: string = '';
  @State private audioUri: string = '';
  @State private audioLoading: boolean = false;
  @State private audioLoadMessage: string = '';
  @State private prepared: boolean = false;
  @State private playing: boolean = false;
  @State private currentTimeMs: number = 0;
  @State private durationMs: number = 0;

  onPauseReady: (pause: () => void) => void = (_pause: () => void) => {};
  onFullscreenRequest: () => void = () => {};
  onFullscreenDismissed: () => void = () => {};
  onMediaStateChanged: (
    imageUris: string[],
    imageIndex: number,
    playing: boolean,
    currentTimeMs: number,
    durationMs: number,
    playbackEnabled: boolean,
    prepared: boolean
  ) => void =
    (_imageUris: string[], _imageIndex: number, _playing: boolean, _currentTimeMs: number,
      _durationMs: number, _playbackEnabled: boolean, _prepared: boolean) => {};
  onFullscreenControlsReady: (
    toggleAudio: () => void,
    seek: (value: number) => void,
    previousImage: () => void,
    nextImage: () => void,
    selectImage: (index: number) => void
  ) => void =
    (_toggleAudio: () => void, _seek: (value: number) => void, _previousImage: () => void,
      _nextImage: () => void, _selectImage: (index: number) => void) => {};
  private readonly player: AssignmentAudioPlayerService = new AssignmentAudioPlayerService();
  private imageResources: AssignmentResource[] = [];
  private audioResource: AssignmentResource | null = null;
  private imageRequestVersion: number = 0;
  private lifecycleVersion: number = 0;

  aboutToAppear(): void {
    this.lifecycleVersion++;
    this.onPauseReady(() => { void this.pauseAudio(); });
    this.onFullscreenControlsReady(
      () => { void this.toggleAudio(); },
      (value: number) => this.player.seek(value),
      () => this.previousImage(),
      () => this.nextImage(),
      (index: number) => this.selectImage(index)
    );
    void this.load(this.lifecycleVersion);
  }

  aboutToDisappear(): void {
    this.lifecycleVersion++;
    this.imageRequestVersion++;
    this.onFullscreenDismissed();
    this.onPauseReady(() => {});
    void this.player.release();
  }

  private notifyMediaState(): void {
    this.onMediaStateChanged(
      this.imageUris.slice(),
      this.imageIndex,
      this.playing,
      this.currentTimeMs,
      this.durationMs,
      this.playbackEnabled,
      this.prepared
    );
  }

  private async load(lifecycleVersion: number): Promise<void> {
    this.loading = true;
    this.message = '';
    this.imageLoadMessage = '';
    this.audioLoadMessage = '';
    this.audioUri = '';
    this.audioResource = null;
    this.audioLoading = false;
    this.prepared = false;
    this.playing = false;
    this.currentTimeMs = 0;
    this.durationMs = 0;
    this.imageResources = [];
    this.imageUris = [];
    this.imageIndex = 0;
    try {
      let resources = await RemoteAssignmentResourceApi.instance.list(this.assignmentId);
      if (lifecycleVersion !== this.lifecycleVersion) return;
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

      images.sort((left: AssignmentResource, right: AssignmentResource) =>
        this.compareImageResources(left, right));
      this.imageResources = images;
      this.audioResource = audio;

      let slots: string[] = [];
      for (let i = 0; i < images.length; i++) slots.push('');
      this.imageUris = slots;

      let firstImageUri = await this.loadImage(0);
      if (lifecycleVersion !== this.lifecycleVersion) return;
      if (firstImageUri.length === 0) {
        this.message = '情景图片加载失败，请检查网络后重试';
        return;
      }

      this.imageIndex = 0;
      this.notifyMediaState();
      this.loading = false;
      void this.prefetchNextImage(0);
      void this.loadAudio(audio);
    } catch {
      this.message = '作业资料加载失败，请检查网络后重试';
    } finally {
      if (lifecycleVersion === this.lifecycleVersion) this.loading = false;
    }
  }

  private async loadAudio(resource: AssignmentResource): Promise<void> {
    if (this.audioLoading) return;
    let lifecycleVersion = this.lifecycleVersion;
    this.audioLoading = true;
    this.audioLoadMessage = '';
    this.prepared = false;
    this.audioUri = '';
    this.notifyMediaState();

    let audioUri = await RemoteAssignmentResourceApi.instance.download(resource);
    if (lifecycleVersion !== this.lifecycleVersion) return;
    if (audioUri.length === 0) {
      this.audioLoading = false;
      this.audioLoadMessage = '语音加载失败，请检查网络后重试';
      return;
    }

    this.audioUri = audioUri;
    let callbacks: AssignmentAudioPlayerCallbacks = {
      onPrepared: (durationMs: number) => {
        this.audioLoading = false;
        this.prepared = true;
        this.durationMs = durationMs;
        this.currentTimeMs = 0;
        this.notifyMediaState();
      },
      onState: (state) => {
        this.playing = state === 'playing';
        if (state === 'completed') this.playing = false;
        this.notifyMediaState();
      },
      onTime: (timeMs: number) => {
        this.currentTimeMs = timeMs;
        this.notifyMediaState();
      },
      onError: (_message: string) => {
        this.audioLoading = false;
        this.playing = false;
        this.audioLoadMessage = '语音播放暂时不可用，请稍后重试';
        this.notifyMediaState();
      }
    };
    await this.player.prepare(this.audioUri, callbacks);
  }

  private retryAudio(): void {
    let resource = this.audioResource;
    if (resource === null || this.audioLoading) return;
    void this.loadAudio(resource);
  }

  private compareImageResources(left: AssignmentResource, right: AssignmentResource): number {
    let leftName = left.originalName.toLowerCase();
    let rightName = right.originalName.toLowerCase();
    let leftIndex = 0;
    let rightIndex = 0;

    while (leftIndex < leftName.length && rightIndex < rightName.length) {
      let leftCode = leftName.charCodeAt(leftIndex);
      let rightCode = rightName.charCodeAt(rightIndex);
      let leftDigit = leftCode >= 48 && leftCode <= 57;
      let rightDigit = rightCode >= 48 && rightCode <= 57;

      if (leftDigit && rightDigit) {
        let leftEnd = leftIndex;
        let rightEnd = rightIndex;
        while (leftEnd < leftName.length) {
          let code = leftName.charCodeAt(leftEnd);
          if (code < 48 || code > 57) break;
          leftEnd++;
        }
        while (rightEnd < rightName.length) {
          let code = rightName.charCodeAt(rightEnd);
          if (code < 48 || code > 57) break;
          rightEnd++;
        }
        let leftNumber = Number(leftName.substring(leftIndex, leftEnd));
        let rightNumber = Number(rightName.substring(rightIndex, rightEnd));
        if (leftNumber !== rightNumber) return leftNumber < rightNumber ? -1 : 1;
        leftIndex = leftEnd;
        rightIndex = rightEnd;
        continue;
      }

      if (leftCode !== rightCode) return leftCode < rightCode ? -1 : 1;
      leftIndex++;
      rightIndex++;
    }

    if (leftName.length !== rightName.length) return leftName.length < rightName.length ? -1 : 1;
    if (left.sortOrder === right.sortOrder) return 0;
    return left.sortOrder < right.sortOrder ? -1 : 1;
  }

  private async loadImage(index: number): Promise<string> {
    if (index < 0 || index >= this.imageResources.length) return '';
    if (index < this.imageUris.length && this.imageUris[index].length > 0) return this.imageUris[index];

    let lifecycleVersion = this.lifecycleVersion;
    let uri = await RemoteAssignmentResourceApi.instance.download(this.imageResources[index]);
    if (lifecycleVersion !== this.lifecycleVersion || uri.length === 0) return '';

    let next = this.imageUris.slice();
    next[index] = uri;
    this.imageUris = next;
    this.notifyMediaState();
    return uri;
  }

  private async prefetchNextImage(index: number): Promise<void> {
    let next = index + 1;
    if (next < 0 || next >= this.imageResources.length) return;
    await this.loadImage(next);
  }

  private async showImage(index: number): Promise<void> {
    if (index < 0 || index >= this.imageResources.length) return;
    if (index === this.imageIndex && index < this.imageUris.length && this.imageUris[index].length > 0) {
      void this.prefetchNextImage(index);
      return;
    }

    let requestVersion = ++this.imageRequestVersion;
    this.imageIndex = index;
    this.imageLoading = true;
    this.imageLoadMessage = '';
    this.notifyMediaState();
    let uri = await this.loadImage(index);
    if (requestVersion !== this.imageRequestVersion) return;

    this.imageLoading = false;
    if (uri.length === 0) {
      this.imageLoadMessage = `第 ${index + 1} 张图片加载失败，请重试`;
      return;
    }

    this.notifyMediaState();
    void this.prefetchNextImage(index);
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

  private previousImage(): void {
    if (this.imageResources.length <= 1) return;
    let index = this.imageIndex <= 0 ? this.imageResources.length - 1 : this.imageIndex - 1;
    void this.showImage(index);
  }

  private nextImage(): void {
    if (this.imageResources.length <= 1) return;
    let index = this.imageIndex >= this.imageResources.length - 1 ? 0 : this.imageIndex + 1;
    void this.showImage(index);
  }

  private selectImage(index: number): void {
    if (index < 0 || index >= this.imageResources.length) return;
    void this.showImage(index);
  }

  private openFullscreen(): void {
    if (this.imageUris.length === 0 || this.imageUris[this.imageIndex].length === 0) return;
    this.notifyMediaState();
    this.onFullscreenRequest();
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
      Stack({ alignContent: Alignment.Center }) {
        Swiper() {
          ForEach(this.imageUris, (uri: string, index: number) => {
            Stack({ alignContent: Alignment.Center }) {
              if (uri.length > 0) {
                Image(uri)
                  .width('100%')
                  .height(286)
                  .objectFit(ImageFit.Contain);
              } else {
                LoadingProgress()
                  .width(28)
                  .height(28)
                  .color(AppTheme.PRIMARY);
              }
            }
            .width('100%')
            .height(286)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS);
          }, (uri: string, index: number) => `${index}-${uri}`);
        }
        .width('100%')
        .height(286)
        .index(this.imageIndex)
        .indicator(false)
        .loop(true)
        .onChange((index: number) => { void this.showImage(index); })
        .borderRadius(AppTheme.CONTROL_RADIUS);

        if (this.imageUris.length > 1) {
          Row() {
            Button('←', { type: ButtonType.Circle })
              .width(42)
              .height(42)
              .fontSize(22)
              .backgroundColor('#CCFFFFFF')
              .fontColor(AppTheme.TEXT)
              .accessibilityText('上一张情景图片')
              .onClick(() => this.previousImage());
            Blank();
            Button('→', { type: ButtonType.Circle })
              .width(42)
              .height(42)
              .fontSize(22)
              .backgroundColor('#CCFFFFFF')
              .fontColor(AppTheme.TEXT)
              .accessibilityText('下一张情景图片')
              .onClick(() => this.nextImage());
          }
          .width('100%')
          .padding({ left: 10, right: 10 });
        }

        Column() {
          Row({ space: 6 }) {
            Blank();
            Text(`${this.imageIndex + 1} / ${this.imageUris.length}`)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .backgroundColor('#66000000')
              .borderRadius(12);
            Button('全屏查看', { type: ButtonType.Normal })
              .width(88)
              .height(36)
              .padding({ left: 10, right: 10 })
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .backgroundColor(AppTheme.PRIMARY)
              .borderRadius(18)
              .accessibilityText('全屏查看图片和语音')
              .onClick(() => this.openFullscreen());
          }
          .width('100%')
          .padding({ top: 10, right: 10 });
          Blank();
        }
        .width('100%')
        .height(286);
      }
      .width('100%');

      if (this.imageUris.length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.imageUris, (uri: string, index: number) => {
              Stack({ alignContent: Alignment.Center }) {
                if (uri.length > 0) {
                  Image(uri)
                    .width(64)
                    .height(54)
                    .objectFit(ImageFit.Cover);
                } else {
                  Text(`${index + 1}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.SUBTEXT);
                }
              }
              .width(64)
              .height(54)
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

      if (this.imageLoading) {
        Text('正在加载图片…')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      } else if (this.imageLoadMessage.length > 0) {
        Text(this.imageLoadMessage)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%');
  }

  @Builder
  private AudioControls() {
    Column({ space: 5 }) {
      if (this.audioLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(AppTheme.PRIMARY);
          Text('正在加载语音…').fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      } else if (this.audioLoadMessage.length > 0) {
        Row({ space: 8 }) {
          Text(this.audioLoadMessage)
            .layoutWeight(1)
            .fontSize(11)
            .fontColor(AppTheme.WARNING);
          Text('重试')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => this.retryAudio());
        }
        .width('100%');
      } else {
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
              Text(this.formatTime(this.currentTimeMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(this.formatTime(this.durationMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
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
          Text('正在加载首张情景图片…').fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (this.message.length > 0) {
        Column({ space: 8 }) {
          Text(this.message).fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.WARNING);
          Text('重新加载')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .fontSize(AppTheme.ACTION_TEXT_SIZE).lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.load(this.lifecycleVersion); });
        }
        .width('100%')
        .padding(14)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(AppTheme.WARNING_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (this.imageUris.length > 0 && this.imageUris[this.imageIndex].length > 0) {
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
