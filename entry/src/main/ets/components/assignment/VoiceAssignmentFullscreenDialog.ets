import { AppTheme } from '../../common/theme/AppTheme';

@CustomDialog
export struct VoiceAssignmentFullscreenDialog {
  controller: CustomDialogController;
  @Link imageUris: string[];
  @Link imageIndex: number;
  @Link playing: boolean;
  @Link currentTimeMs: number;
  @Link durationMs: number;
  @Link playbackEnabled: boolean;
  @Link prepared: boolean;

  onToggleAudio: () => void = () => {};
  onSeek: (value: number) => void = (_value: number) => {};

  private previousImage(): void {
    if (this.imageUris.length <= 1) return;
    this.imageIndex = this.imageIndex <= 0 ? this.imageUris.length - 1 : this.imageIndex - 1;
  }

  private nextImage(): void {
    if (this.imageUris.length <= 1) return;
    this.imageIndex = this.imageIndex >= this.imageUris.length - 1 ? 0 : this.imageIndex + 1;
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
  private FullscreenImage() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.imageUris[this.imageIndex])
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .backgroundColor('#111111');

      if (this.imageUris.length > 1) {
        Row() {
          Button('‹', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(30)
            .backgroundColor('#CCFFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('上一张情景图片')
            .onClick(() => this.previousImage());
          Blank();
          Button('›', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(30)
            .backgroundColor('#CCFFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('下一张情景图片')
            .onClick(() => this.nextImage());
        }
        .width('100%')
        .padding({ left: 12, right: 12 });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  private ThumbnailStrip() {
    if (this.imageUris.length > 1) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.imageUris, (uri: string, index: number) => {
            Image(uri)
              .width(68)
              .height(56)
              .objectFit(ImageFit.Cover)
              .border({
                width: index === this.imageIndex ? 2 : 1,
                color: index === this.imageIndex ? AppTheme.PRIMARY : '#666666'
              })
              .borderRadius(10)
              .backgroundColor('#242424')
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

  @Builder
  private FullscreenAudioControls() {
    Row({ space: 12 }) {
      Button(this.playing ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
        .width(52)
        .height(52)
        .fontSize(this.playing ? 19 : 17)
        .enabled(this.playbackEnabled && this.prepared)
        .backgroundColor(this.playbackEnabled && this.prepared ? AppTheme.PRIMARY : '#555555')
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .accessibilityText(this.playing ? '暂停语音' : '播放语音')
        .onClick(() => this.onToggleAudio());

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
              this.onSeek(value);
            }
          });

        Row() {
          Text(this.formatTime(this.currentTimeMs)).fontSize(11).fontColor('#D8D8D8');
          Blank();
          Text(this.formatTime(this.durationMs)).fontSize(11).fontColor('#D8D8D8');
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding({ top: 8, bottom: 4 });
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(`${this.imageIndex + 1} / ${this.imageUris.length}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF');
        Blank();
        Text('关闭')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 14, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('退出全屏')
          .onClick(() => this.controller.close());
      }
      .width('100%');

      this.FullscreenImage();
      this.ThumbnailStrip();
      this.FullscreenAudioControls();
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#111111');
  }
}
