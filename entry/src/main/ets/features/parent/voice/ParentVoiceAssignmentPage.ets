import { VoiceAssignmentMediaService } from '../../../application/assignment/VoiceAssignmentMediaService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeadlinePickerField } from '../../../components/assignment/DeadlinePickerField';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';
import { ParentVoiceAssignmentViewModel, VoiceAssignmentDraft } from './ParentVoiceAssignmentViewModel';

@Component
export struct ParentVoiceAssignmentPage {
  @State private subject: Subject = Subject.ENGLISH;
  @State private title: string = '';
  @State private instruction: string = '';
  @State private dueText: string = '今天';
  @State private expectedMinutesText: string = '15';
  @State private audioUri: string = '';
  @State private audioName: string = '';
  @State private imageUris: string[] = [];
  @State private busy: boolean = false;
  @State private selectingAudio: boolean = false;
  @State private selectingImages: boolean = false;
  @State private message: string = '';
  @State private messageError: boolean = false;

  onBack: () => void = () => {};
  onCreated: () => void = () => {};

  private readonly viewModel: ParentVoiceAssignmentViewModel =
    new ParentVoiceAssignmentViewModel(DefaultAssignmentRepository.instance);

  private expectedMinutes(): number {
    let value = Number(this.expectedMinutesText.trim());
    if (!Number.isFinite(value) || value < 1 || value > 240 || Math.floor(value) !== value) return -1;
    return value;
  }

  private dueAtEpochMs(): number {
    let text = this.dueText.trim();
    if (text.length === 0) return 0;
    let value = AssignmentDueDate.resolveDueAtEpochMs(text, Date.now());
    return value > 0 ? value : -1;
  }

  private async selectAudio(): Promise<void> {
    if (this.selectingAudio || this.busy) return;
    this.selectingAudio = true;
    let uri = await VoiceAssignmentMediaService.instance.selectAudio();
    this.selectingAudio = false;
    if (uri.length === 0) return;
    this.audioUri = uri;
    this.audioName = VoiceAssignmentMediaService.instance.displayName(uri, '语音文件');
    this.message = '';
  }

  private async selectImages(): Promise<void> {
    if (this.selectingImages || this.busy) return;
    this.selectingImages = true;
    let uris = await VoiceAssignmentMediaService.instance.selectImages();
    this.selectingImages = false;
    if (uris.length === 0) return;

    let merged = this.imageUris.slice();
    let existing: Set<string> = new Set<string>();
    for (let uri of merged) existing.add(uri);
    for (let uri of uris) {
      if (existing.has(uri)) continue;
      existing.add(uri);
      merged.push(uri);
    }
    this.imageUris = merged;
    this.message = '';
    this.messageError = false;
  }

  private removeImage(index: number): void {
    let next: string[] = [];
    for (let i = 0; i < this.imageUris.length; i++) {
      if (i !== index) next.push(this.imageUris[i]);
    }
    this.imageUris = next;
  }

  private async createTask(): Promise<void> {
    if (this.busy) return;
    let title = this.title.trim();
    let instruction = this.instruction.trim();
    if (title.length === 0) return this.showError('请填写作业名称');
    if (instruction.length === 0) return this.showError('请填写完成要求');
    if (this.audioUri.length === 0) return this.showError('请选择一个语音文件');
    if (this.imageUris.length === 0) return this.showError('请选择至少 1 张情景图片');

    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) return this.showError('预计用时请输入 1～240 分钟的整数');
    let dueAt = this.dueAtEpochMs();
    if (dueAt < 0) return this.showError('请选择有效的截止日期和时间');

    this.busy = true;
    this.message = '';
    this.messageError = false;
    try {
      let draft: VoiceAssignmentDraft = {
        subject: this.subject,
        title: title,
        instruction: instruction,
        dueAtEpochMs: dueAt,
        dueText: dueAt > 0 ? this.dueText.trim() : '未定',
        expectedMinutes: expectedMinutes
      };
      await this.viewModel.create(draft, this.audioUri, this.imageUris);
      this.message = `已布置给 ${this.viewModel.student().name}`;
      this.onCreated();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '语音作业发布失败，请稍后重试';
      this.messageError = true;
    } finally {
      this.busy = false;
    }
  }

  private showError(message: string): void {
    this.message = message;
    this.messageError = true;
  }

  @Builder
  private SubjectOption(label: string, value: Subject) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.subject === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.subject === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.subject === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.subject = value);
  }

  @Builder
  private BasicSection() {
    Column({ space: 12 }) {
      Text('作业信息').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Row({ space: 8 }) {
        this.SubjectOption('英语', Subject.ENGLISH);
        this.SubjectOption('语文', Subject.CHINESE);
        this.SubjectOption('其他', Subject.OTHER);
      }
      .width('100%');

      TextInput({ placeholder: '例如：Unit 3 情景对话跟读', text: this.title })
        .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(15)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.title = value);

      TextArea({ placeholder: '例如：先听完整对话，再看图片跟读 2 遍', text: this.instruction })
        .width('100%').height(108).fontSize(14).lineHeight(21)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.instruction = value);
    }
    .width('100%');
  }

  @Builder
  private AudioSection() {
    Column({ space: 10 }) {
      Row() {
        Text('语音文件').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text('1 个').fontSize(11).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.audioUri.length === 0) {
        Button(this.selectingAudio ? '正在打开语音文件…' : '选择语音文件', { type: ButtonType.Normal })
          .width('100%').height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
          .enabled(!this.selectingAudio && !this.busy)
          .onClick(() => { void this.selectAudio(); });
      } else {
        Row({ space: 10 }) {
          Text('♪')
            .width(38).height(38).fontSize(22).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY).textAlign(TextAlign.Center)
            .backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(10);
          Column({ space: 2 }) {
            Text(this.audioName).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start);
          Text('更换')
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 8, right: 8 })
            .textAlign(TextAlign.Center)
            .onClick(() => { void this.selectAudio(); });
        }
        .width('100%')
        .padding(10)
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }
      Text('支持 mp3 / m4a / wav，单个文件不超过 20MB。')
        .width('100%').fontSize(11).fontColor(AppTheme.SUBTEXT);
    }
    .width('100%');
  }

  @Builder
  private ImageSection() {
    Column({ space: 10 }) {
      Row() {
        Text('情景图片').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`已选择 ${this.imageUris.length} 张`).fontSize(11).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.imageUris.length > 0) {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.imageUris, (uri: string, index: number) => {
              Stack({ alignContent: Alignment.TopEnd }) {
                Image(uri)
                  .width(88).height(88).objectFit(ImageFit.Cover)
                  .borderRadius(12).backgroundColor(AppTheme.SURFACE_EMPHASIS);
                Text('×')
                  .width(28).height(28).fontSize(16).fontColor(AppTheme.TEXT_ON_PRIMARY)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#88000000').borderRadius(14)
                  .onClick(() => this.removeImage(index));
              }
              .width(88).height(88);
            }, (uri: string, index: number) => `${index}-${uri}`);
          }
        }
        .width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
      }

      Button(this.selectingImages ? '正在打开相册…' :
        (this.imageUris.length === 0 ? '选择情景图片' : '＋ 继续添加图片'), { type: ButtonType.Normal })
        .width('100%').height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
        .enabled(!this.selectingImages && !this.busy)
        .onClick(() => { void this.selectImages(); });

    }
    .width('100%');
  }

  @Builder
  private TimingSection() {
    Column({ space: 10 }) {
      Text('时间安排').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      DeadlinePickerField({
        value: this.dueText,
        allowClear: true,
        onChange: (value: string) => this.dueText = value
      });
      Column({ space: 5 }) {
        Text('预计用时（分钟）').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '15', text: this.expectedMinutesText })
          .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(14)
          .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.expectedMinutesText = value);
      }
      .width('100%').alignItems(HorizontalAlign.Start);
    }
    .width('100%');
  }

  @Builder
  private Feedback() {
    if (this.message.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.messageError ? $r('sys.symbol.exclamationmark_circle_fill') : $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17).fontColor([this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS]);
        Text(this.message).layoutWeight(1).fontSize(13).lineHeight(19)
          .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%').padding(12)
      .backgroundColor(this.messageError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '布置语音作业',
          subtitle: `上传语音和配套图片，${this.viewModel.student().name} 可以边听边看`,
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 18 }) {
              this.BasicSection();
              Divider().color(AppTheme.DIVIDER);
              this.AudioSection();
              Divider().color(AppTheme.DIVIDER);
              this.ImageSection();
              Divider().color(AppTheme.DIVIDER);
              this.TimingSection();
            }
            .width('100%')
            .padding(AppTheme.PHONE_CARD_PADDING)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);

            this.Feedback();

            Button(this.busy ? '正在发布…' : '发布语音作业', { type: ButtonType.Normal })
              .width('100%').height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.busy)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.createTask(); });
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off);
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_REVIEW_READABLE_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: AppTheme.DEEP_PAGE_TOP_PADDING });
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
