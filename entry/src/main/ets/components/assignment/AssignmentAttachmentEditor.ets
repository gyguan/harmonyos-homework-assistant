import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { VoiceAssignmentMediaService } from '../../application/assignment/VoiceAssignmentMediaService';
import { RemoteAssignmentResourceApi } from '../../application/remote/RemoteAssignmentResourceApi';
import { AppTheme } from '../../common/theme/AppTheme';
import { AssignmentResource, AssignmentResourceType } from '../../domain/model/HomeworkModels';

/** Attachments are optional and independent of the legacy voice-assignment workflow. */
@Component
export struct AssignmentAttachmentEditor {
  @Prop @Watch('reload') assignmentId: string = '';
  @State private items: AssignmentResource[] = [];
  @State private busy: boolean = false;
  @State private feedback: string = '';
  @State private previewUri: string = '';
  @State private previewType: AssignmentResourceType = AssignmentResourceType.IMAGE;
  private readonly api: RemoteAssignmentResourceApi = RemoteAssignmentResourceApi.instance;

  aboutToAppear(): void { void this.reload(); }

  private async reload(): Promise<void> {
    if (this.assignmentId.length === 0) return;
    try { this.items = await this.api.list(this.assignmentId); }
    catch { this.feedback = '附件加载失败，请重试'; }
  }

  private async choose(type: AssignmentResourceType): Promise<void> {
    if (this.busy || this.items.length >= 10) return;
    let uris: string[] = [];
    try {
      if (type === AssignmentResourceType.AUDIO) {
        let one = await VoiceAssignmentMediaService.instance.selectAudio();
        if (one.length > 0) uris.push(one);
      } else {
        let picker = new photoAccessHelper.PhotoViewPicker();
        let result = await picker.select({
          MIMEType: type === AssignmentResourceType.VIDEO ?
            photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
          maxSelectNumber: 10 - this.items.length
        });
        uris = result.photoUris;
      }
      if (uris.length === 0) return;
      this.busy = true;
      this.feedback = '';
      for (let uri of uris) {
        await this.api.uploadAttachment(this.assignmentId, uri, type);
      }
      await this.reload();
    } catch (error) {
      this.feedback = error instanceof Error ? error.message : '添加附件失败';
      await this.reload();
    } finally {
      this.busy = false;
    }
  }

  private async remove(id: string): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.api.removeAttachment(this.assignmentId, id);
      await this.reload();
    } catch {
      this.feedback = '删除失败，请重试';
    } finally { this.busy = false; }
  }

  private async preview(item: AssignmentResource): Promise<void> {
    this.feedback = '';
    let uri = await this.api.download(item);
    if (uri.length === 0) { this.feedback = '附件下载失败，请重试'; return; }
    this.previewType = item.resourceType;
    this.previewUri = uri;
  }

  @Builder
  private AddButton(label: string, kind: AssignmentResourceType) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .fontSize(13)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .fontColor(AppTheme.PRIMARY)
      .enabled(!this.busy && this.items.length < 10)
      .onClick(() => { void this.choose(kind); });
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('作业附件（选填）').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium);
        Blank();
        Text(this.items.length + '/10').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Row({ space: 8 }) {
        this.AddButton('＋ 图片', AssignmentResourceType.IMAGE);
        this.AddButton('＋ 语音', AssignmentResourceType.AUDIO);
        this.AddButton('＋ 视频', AssignmentResourceType.VIDEO);
      }.width('100%');
      ForEach(this.items, (item: AssignmentResource) => {
        Row({ space: 8 }) {
          Text(item.resourceType === AssignmentResourceType.IMAGE ? '图片' :
            (item.resourceType === AssignmentResourceType.VIDEO ? '视频' : '语音'))
            .fontSize(12).fontColor(AppTheme.PRIMARY);
          Text(item.originalName).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
          Button('查看', { type: ButtonType.Normal })
            .fontSize(12).backgroundColor(AppTheme.SURFACE_SUBTLE).fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.preview(item); });
          Button('删除', { type: ButtonType.Normal })
            .fontSize(12).backgroundColor(AppTheme.SURFACE_SUBTLE).fontColor(AppTheme.DANGER)
            .enabled(!this.busy).onClick(() => { void this.remove(item.id); });
        }.width('100%');
      }, (item: AssignmentResource) => item.id);
      if (this.busy) Text('附件上传中…').fontSize(12).fontColor(AppTheme.SUBTEXT);
      if (this.feedback.length > 0) Text(this.feedback).fontSize(12).fontColor(AppTheme.DANGER);
      if (this.previewUri.length > 0) {
        if (this.previewType === AssignmentResourceType.IMAGE) {
          Image(this.previewUri).width('100%').height(220).objectFit(ImageFit.Contain);
        } else if (this.previewType === AssignmentResourceType.VIDEO) {
          Video({ src: this.previewUri }).width('100%').height(220).controls(true);
        } else {
          Text('语音文件已下载，可在学生端播放').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        Button('关闭预览', { type: ButtonType.Normal })
          .onClick(() => this.previewUri = '');
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }
}
