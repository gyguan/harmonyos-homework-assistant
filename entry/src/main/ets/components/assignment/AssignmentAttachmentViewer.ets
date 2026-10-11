import {
  AssignmentAudioPlayerCallbacks,
  AssignmentAudioPlayerService
} from '../../application/assignment/AssignmentAudioPlayerService';
import { RemoteAssignmentResourceApi } from '../../application/remote/RemoteAssignmentResourceApi';
import { AppTheme } from '../../common/theme/AppTheme';
import { AssignmentResource, AssignmentResourceType } from '../../domain/model/HomeworkModels';

@Component
export struct AssignmentAttachmentViewer {
  @Prop @Watch('reload') assignmentId: string = '';
  @State private resources: AssignmentResource[] = [];
  @State private selectedUri: string = '';
  @State private selectedType: AssignmentResourceType = AssignmentResourceType.IMAGE;
  @State private selectedName: string = '';
  @State private audioReady: boolean = false;
  @State private audioPlaying: boolean = false;
  @State private message: string = '';
  private readonly api: RemoteAssignmentResourceApi = RemoteAssignmentResourceApi.instance;
  private readonly player: AssignmentAudioPlayerService = new AssignmentAudioPlayerService();

  aboutToAppear(): void { void this.reload(); }
  aboutToDisappear(): void { void this.player.release(); }

  private async reload(): Promise<void> {
    await this.player.release();
    this.resources = [];
    this.selectedUri = '';
    if (this.assignmentId.length === 0) return;
    try { this.resources = await this.api.list(this.assignmentId); }
    catch { this.message = '暂时无法加载作业附件'; }
  }

  private async open(item: AssignmentResource): Promise<void> {
    await this.player.release();
    this.audioReady = false;
    this.audioPlaying = false;
    this.selectedUri = '';
    this.message = '';
    const uri = await this.api.download(item);
    if (uri.length === 0) { this.message = '附件加载失败，请检查网络'; return; }
    this.selectedUri = uri;
    this.selectedType = item.resourceType;
    this.selectedName = item.originalName;
    if (item.resourceType === AssignmentResourceType.AUDIO) {
      let callbacks: AssignmentAudioPlayerCallbacks = {
        onPrepared: (_duration: number) => { this.audioReady = true; },
        onState: (state) => { this.audioPlaying = state === 'playing'; },
        onTime: (_time: number) => {},
        onError: (error: string) => { this.message = error; }
      };
      await this.player.prepare(uri, callbacks);
    }
  }

  private async toggleAudio(): Promise<void> {
    if (!this.audioReady) return;
    if (this.audioPlaying) await this.player.pause();
    else await this.player.play();
  }

  build() {
    if (this.resources.length > 0) {
      Column({ space: 10 }) {
        Text('学习资料')
          .width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        ForEach(this.resources, (item: AssignmentResource) => {
          Row({ space: 12 }) {
            Text(item.resourceType === AssignmentResourceType.IMAGE ? '图片' :
              (item.resourceType === AssignmentResourceType.VIDEO ? '视频' : '语音'))
              .fontSize(13).fontColor(AppTheme.PRIMARY);
            Text(item.originalName).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(AppTheme.TEXT);
            Text('查看 ›').fontSize(13).fontColor(AppTheme.PRIMARY);
          }
          .width('100%').height(AppTheme.MIN_TOUCH_TARGET)
          .onClick(() => { void this.open(item); });
        }, (item: AssignmentResource) => item.id);
        if (this.selectedUri.length > 0) {
          if (this.selectedType === AssignmentResourceType.IMAGE) {
            Image(this.selectedUri).width('100%').height(280).objectFit(ImageFit.Contain);
          } else if (this.selectedType === AssignmentResourceType.VIDEO) {
            Video({ src: this.selectedUri }).width('100%').height(250).controls(true);
          } else {
            Button(this.audioPlaying ? '暂停语音' : '播放语音', { type: ButtonType.Normal })
              .enabled(this.audioReady)
              .width('100%').height(AppTheme.MIN_TOUCH_TARGET)
              .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.toggleAudio(); });
          }
          Button('收起资料', { type: ButtonType.Normal })
            .width('100%').onClick(() => {
              void this.player.release(); this.selectedUri = ''; this.audioReady = false;
            });
        }
        if (this.message.length > 0) Text(this.message).fontColor(AppTheme.DANGER).fontSize(12);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }
}
