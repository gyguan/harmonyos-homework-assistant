import { AssignmentAudioPlayerService } from '../../application/assignment/AssignmentAudioPlayerService';
import {
  RemoteSubmissionApi,
  RemoteSubmissionResource
} from '../../application/remote/RemoteSubmissionApi';
import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct SubmissionAudioEvidencePlayer {
  @Prop @Watch('onSourceChanged') resource: RemoteSubmissionResource | null = null;
  @Prop @Watch('onSourceChanged') localUri: string = '';
  @Prop fallbackDurationMs: number = 0;
  @State private loading: boolean = false;
  @State private sourceUri: string = '';
  @State private prepared: boolean = false;
  @State private playing: boolean = false;
  @State private currentMs: number = 0;
  @State private durationMs: number = 0;
  @State private notice: string = '';
  private loadSequence: number = 0;
  private readonly player: AssignmentAudioPlayerService = new AssignmentAudioPlayerService();

  aboutToAppear(): void {
    void this.prepareSource();
  }

  aboutToDisappear(): void {
    this.loadSequence++;
    void this.player.release();
  }

  private onSourceChanged(): void {
    this.loadSequence++;
    void this.player.release();
    this.sourceUri = '';
    this.prepared = false;
    this.playing = false;
    this.currentMs = 0;
    this.durationMs = this.resource !== null && this.resource.durationMs > 0 ?
      this.resource.durationMs : this.fallbackDurationMs;
    this.notice = '';
    void this.prepareSource();
  }

  private async prepareSource(): Promise<void> {
    if (this.loading) return;
    let sequence = ++this.loadSequence;
    this.loading = true;
    this.notice = '';
    try {
      let uri = this.localUri;
      if (uri.length === 0 && this.resource !== null) {
        uri = await RemoteSubmissionApi.instance.downloadResource(this.resource);
      }
      if (sequence !== this.loadSequence) return;
      if (uri.length === 0) {
        this.notice = '学生录音暂不可用';
        return;
      }
      this.sourceUri = uri;
      await this.player.prepare(uri, {
        onPrepared: (durationMs: number) => {
          if (sequence !== this.loadSequence) return;
          this.prepared = true;
          if (durationMs > 0) this.durationMs = durationMs;
        },
        onState: (state) => {
          if (sequence !== this.loadSequence) return;
          this.playing = state === 'playing';
          if (state === 'completed') this.currentMs = this.durationMs;
        },
        onTime: (timeMs: number) => {
          if (sequence === this.loadSequence) this.currentMs = timeMs;
        },
        onError: (_message: string) => {
          if (sequence !== this.loadSequence) return;
          this.playing = false;
          this.notice = '学生录音播放失败';
        }
      });
    } finally {
      if (sequence === this.loadSequence) this.loading = false;
    }
  }

  private async toggle(): Promise<void> {
    if (!this.prepared) {
      if (!this.loading) void this.prepareSource();
      return;
    }
    if (this.playing) await this.player.pause();
    else await this.player.play();
  }

  private formatTime(ms: number): string {
    let totalSeconds = Math.max(0, Math.floor(ms / 1000));
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Button(this.playing ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
          .width(48)
          .height(48)
          .enabled(this.prepared && !this.loading)
          .backgroundColor(this.prepared ? AppTheme.PRIMARY : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .accessibilityText(this.playing ? '暂停学生录音' : '播放学生录音')
          .onClick(() => { void this.toggle(); });

        Column({ space: 3 }) {
          Text('学生录音')
            .fontSize(AppTheme.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(`${this.formatTime(this.currentMs)} / ${this.formatTime(this.durationMs)}`)
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        if (this.loading) {
          Text('加载中')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.durationMs > 0) {
        Progress({
          value: Math.min(this.currentMs, this.durationMs),
          total: this.durationMs,
          type: ProgressType.Linear
        })
          .width('100%')
          .color(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS);
      }

      if (this.notice.length > 0) {
        Text(this.notice)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
