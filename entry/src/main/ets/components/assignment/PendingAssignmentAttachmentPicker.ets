import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { VoiceAssignmentMediaService } from '../../application/assignment/VoiceAssignmentMediaService';
import { AppTheme } from '../../common/theme/AppTheme';
import { AssignmentResourceType } from '../../domain/model/HomeworkModels';

export interface PendingAssignmentAttachment {
  candidateId: string;
  resourceType: AssignmentResourceType;
  uri: string;
  displayName: string;
}

@Component
export struct PendingAssignmentAttachmentPicker {
  @Prop candidateId: string = '';
  @Prop attachments: PendingAssignmentAttachment[] = [];
  @Prop disabled: boolean = false;
  onChange: (attachments: PendingAssignmentAttachment[]) => void =
    (_attachments: PendingAssignmentAttachment[]) => {};

  private remaining(): number {
    return Math.max(0, 10 - this.attachments.length);
  }

  private async chooseImages(): Promise<void> {
    if (this.disabled || this.remaining() <= 0) return;
    try {
      let picker = new photoAccessHelper.PhotoViewPicker();
      let result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: this.remaining()
      });
      let next: PendingAssignmentAttachment[] = this.attachments.slice();
      for (let uri of result.photoUris) {
        if (next.length >= 10) break;
        next.push({
          candidateId: this.candidateId,
          resourceType: AssignmentResourceType.IMAGE,
          uri: uri,
          displayName: VoiceAssignmentMediaService.instance.displayName(uri, '作业图片')
        });
      }
      this.onChange(next);
    } catch {}
  }

  private async chooseVideo(): Promise<void> {
    if (this.disabled || this.remaining() <= 0) return;
    try {
      let picker = new photoAccessHelper.PhotoViewPicker();
      let result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) return;
      let uri = result.photoUris[0];
      let next: PendingAssignmentAttachment[] = this.attachments.slice();
      next.push({
        candidateId: this.candidateId,
        resourceType: AssignmentResourceType.VIDEO,
        uri: uri,
        displayName: VoiceAssignmentMediaService.instance.displayName(uri, '作业视频')
      });
      this.onChange(next);
    } catch {}
  }

  private async chooseAudio(): Promise<void> {
    if (this.disabled || this.remaining() <= 0) return;
    let uri = await VoiceAssignmentMediaService.instance.selectAudio();
    if (uri.length === 0) return;
    let next: PendingAssignmentAttachment[] = this.attachments.slice();
    next.push({
      candidateId: this.candidateId,
      resourceType: AssignmentResourceType.AUDIO,
      uri: uri,
      displayName: VoiceAssignmentMediaService.instance.displayName(uri, '作业语音')
    });
    this.onChange(next);
  }

  private removeAt(index: number): void {
    if (this.disabled) return;
    let next: PendingAssignmentAttachment[] = [];
    for (let i = 0; i < this.attachments.length; i++) {
      if (i !== index) next.push(this.attachments[i]);
    }
    this.onChange(next);
  }

  @Builder
  private AddButton(label: string, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(38)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .fontColor(AppTheme.PRIMARY)
      .enabled(!this.disabled && this.remaining() > 0)
      .onClick(action);
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('作业附件（选填）')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        Blank();
        if (this.attachments.length > 0) {
          Text(`${this.attachments.length}/10`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
      }
      .width('100%');

      Row({ space: 8 }) {
        this.AddButton('＋ 图片', () => { void this.chooseImages(); });
        this.AddButton('＋ 语音', () => { void this.chooseAudio(); });
        this.AddButton('＋ 视频', () => { void this.chooseVideo(); });
      }
      .width('100%');

      if (this.attachments.length > 0) {
        Column({ space: 4 }) {
          ForEach(this.attachments, (item: PendingAssignmentAttachment, index: number) => {
            Row({ space: 8 }) {
              Text(item.resourceType === AssignmentResourceType.IMAGE ? '图片' :
                (item.resourceType === AssignmentResourceType.VIDEO ? '视频' : '语音'))
                .fontSize(12)
                .fontColor(AppTheme.PRIMARY);
              Text(item.displayName)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontSize(12)
                .fontColor(AppTheme.TEXT);
              Text('移除')
                .fontSize(12)
                .fontColor(AppTheme.DANGER)
                .padding({ left: 8, right: 2, top: 6, bottom: 6 })
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .onClick(() => this.removeAt(index));
            }
            .width('100%');
          }, (item: PendingAssignmentAttachment) =>
            `${item.candidateId}|${item.resourceType}|${item.uri}`);
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
