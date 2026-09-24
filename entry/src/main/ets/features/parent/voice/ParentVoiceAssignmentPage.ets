import { VoiceAssignmentMediaService } from '../../../application/assignment/VoiceAssignmentMediaService';
import { RemoteVoiceFolderItem } from '../../../application/remote/RemoteVoiceMaterialApi';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeadlinePickerField } from '../../../components/assignment/DeadlinePickerField';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';
import { ParentVoiceAssignmentViewModel, VoiceAssignmentDraft } from './ParentVoiceAssignmentViewModel';

const VOICE_SOURCE_LOCAL: string = 'LOCAL';
const VOICE_SOURCE_SERVER: string = 'SERVER';

@Component
export struct ParentVoiceAssignmentPage {
  @State private sourceMode: string = VOICE_SOURCE_LOCAL;
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

  @State private folderKeyword: string = '';
  @State private folderUsage: string = 'ALL';
  @State private folders: RemoteVoiceFolderItem[] = [];
  @State private folderPage: number = 0;
  @State private folderTotalPages: number = 0;
  @State private loadingFolders: boolean = false;
  @State private selectedFolderId: string = '';
  @State private requestId: string = '';

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

  private selectedFolder(): RemoteVoiceFolderItem | null {
    for (let item of this.folders) {
      if (item.packageId === this.selectedFolderId) return item;
    }
    return null;
  }

  private switchSource(mode: string): void {
    if (this.busy || this.sourceMode === mode) return;
    this.sourceMode = mode;
    this.message = '';
    this.messageError = false;
    if (mode === VOICE_SOURCE_SERVER && this.folders.length === 0) void this.loadFolders(true);
  }

  private selectFolder(item: RemoteVoiceFolderItem): void {
    if (item.folderStatus !== 'READY' || this.busy) return;
    this.selectedFolderId = item.packageId;
    this.subject = this.viewModel.subjectFromCode(item.subjectCode);
    this.expectedMinutesText = `${item.expectedMinutes > 0 ? item.expectedMinutes : 15}`;
    if (this.title.trim().length === 0) {
      this.title = this.subjectLabel(item.subjectCode) + ' · 语音作业';
    }
    this.requestId = '';
    this.message = '';
  }

  private async loadFolders(reset: boolean): Promise<void> {
    if (this.loadingFolders) return;
    this.loadingFolders = true;
    this.message = '';
    this.messageError = false;
    try {
      let targetPage = reset ? 0 : this.folderPage + 1;
      let result = await this.viewModel.queryFolders(
        this.folderKeyword.trim(), this.folderUsage, targetPage, 20);
      this.folders = reset ? result.items : this.folders.concat(result.items);
      this.folderPage = result.page;
      this.folderTotalPages = result.totalPages;
      if (reset && this.selectedFolderId.length > 0 && this.selectedFolder() === null) {
        this.selectedFolderId = '';
      }
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '读取服务器语音文件夹失败');
    } finally {
      this.loadingFolders = false;
    }
  }

  private setUsageFilter(value: string): void {
    if (this.folderUsage === value || this.loadingFolders) return;
    this.folderUsage = value;
    this.selectedFolderId = '';
    void this.loadFolders(true);
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

  private createRequestId(folderId: string): string {
    if (this.requestId.length > 0) return this.requestId;
    let value = `app-${this.viewModel.student().id}-${folderId}-${Date.now()}`;
    this.requestId = value;
    return value;
  }

  private async createTask(): Promise<void> {
    if (this.busy) return;
    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) return this.showError('预计用时请输入 1～240 分钟的整数');
    let dueAt = this.dueAtEpochMs();
    if (dueAt < 0) return this.showError('请选择有效的截止日期和时间');

    if (this.sourceMode === VOICE_SOURCE_LOCAL) {
      let localTitle = this.title.trim();
      let localInstruction = this.instruction.trim();
      if (localTitle.length === 0) return this.showError('请填写作业名称');
      if (localInstruction.length === 0) return this.showError('请填写完成要求');
      if (this.audioUri.length === 0) return this.showError('请选择一个语音文件');
      if (this.imageUris.length === 0) return this.showError('请选择至少 1 张情景图片');
    } else if (this.selectedFolder() === null) {
      return this.showError('请选择一个服务器语音文件夹');
    }

    this.busy = true;
    this.message = '';
    this.messageError = false;
    try {
      let draft: VoiceAssignmentDraft = {
        subject: this.sourceMode === VOICE_SOURCE_SERVER && this.selectedFolder() !== null ?
          this.viewModel.subjectFromCode(this.selectedFolder()!.subjectCode) : this.subject,
        title: this.title.trim(),
        instruction: this.instruction.trim(),
        dueAtEpochMs: dueAt,
        dueText: dueAt > 0 ? this.dueText.trim() : '未定',
        expectedMinutes: expectedMinutes
      };

      if (this.sourceMode === VOICE_SOURCE_SERVER) {
        let folder = this.selectedFolder()!;
        let created = await this.viewModel.createFromFolder(
          draft, folder, this.createRequestId(folder.packageId));
        if (created === null) {
          this.message = '创建请求已处理，请返回首页刷新查看';
        } else {
          this.message = `已布置给 ${this.viewModel.student().name}`;
        }
      } else {
        await this.viewModel.create(draft, this.audioUri, this.imageUris);
        this.message = `已布置给 ${this.viewModel.student().name}`;
      }
      this.onCreated();
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '语音作业发布失败，请稍后重试');
    } finally {
      this.busy = false;
    }
  }

  private showError(message: string): void {
    this.message = message;
    this.messageError = true;
  }

  private folderUsageText(item: RemoteVoiceFolderItem): string {
    if (item.activeTaskCount > 0) return '当前已有任务';
    if (item.usageCount > 0) return `已使用 ${item.usageCount} 次`;
    return '未使用';
  }

  private subjectLabel(code: string): string {
    if (code === 'CHINESE') return '语文';
    if (code === 'MATH') return '数学';
    if (code === 'ENGLISH') return '英语';
    return '其他';
  }

  @Builder
  private SourceSelector() {
    Column({ space: 8 }) {
      Text('素材来源')
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Row({ space: 8 }) {
        Button('本地文件', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.MIN_TOUCH_TARGET)
          .borderRadius(AppTheme.CHIP_RADIUS)
          .fontWeight(this.sourceMode === VOICE_SOURCE_LOCAL ? FontWeight.Medium : FontWeight.Normal)
          .backgroundColor(this.sourceMode === VOICE_SOURCE_LOCAL ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
          .fontColor(this.sourceMode === VOICE_SOURCE_LOCAL ? AppTheme.PRIMARY : AppTheme.TEXT)
          .onClick(() => this.switchSource(VOICE_SOURCE_LOCAL));

        Button('服务器文件夹', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.MIN_TOUCH_TARGET)
          .borderRadius(AppTheme.CHIP_RADIUS)
          .fontWeight(this.sourceMode === VOICE_SOURCE_SERVER ? FontWeight.Medium : FontWeight.Normal)
          .backgroundColor(this.sourceMode === VOICE_SOURCE_SERVER ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
          .fontColor(this.sourceMode === VOICE_SOURCE_SERVER ? AppTheme.PRIMARY : AppTheme.TEXT)
          .onClick(() => this.switchSource(VOICE_SOURCE_SERVER));
      }
      .width('100%');
    }
    .width('100%');
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
  private LocalBasicSection() {
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
        Text('1 个').fontSize(12).fontColor(AppTheme.SUBTEXT);
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
          Text(this.audioName)
            .layoutWeight(1)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text('更换')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
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
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%');
  }

  @Builder
  private ImageSection() {
    Column({ space: 10 }) {
      Row() {
        Text('情景图片').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`已选择 ${this.imageUris.length} 张`).fontSize(12).fontColor(AppTheme.SUBTEXT);
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
  private UsageChip(label: string, value: string) {
    Button(label, { type: ButtonType.Normal })
      .height(36)
      .padding({ left: 12, right: 12 })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(this.folderUsage === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.folderUsage === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.folderUsage === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.setUsageFilter(value));
  }

  @Builder
  private FolderCard(item: RemoteVoiceFolderItem) {
    Row({ space: 10 }) {
      Text(this.selectedFolderId === item.packageId ? '✓' : '')
        .width(28)
        .height(28)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedFolderId === item.packageId ? AppTheme.TEXT_ON_PRIMARY : AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.selectedFolderId === item.packageId ? AppTheme.PRIMARY : AppTheme.SURFACE_EMPHASIS)
        .borderRadius(14);

      Column({ space: 4 }) {
        Text(item.directoryName)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${this.subjectLabel(item.subjectCode)} · ${item.audioCount} 个语音 · ${item.imageCount} 张图片`)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        Text(this.folderUsageText(item))
          .width('100%')
          .fontSize(12)
          .fontColor(item.activeTaskCount > 0 ? AppTheme.WARNING :
            (item.usageCount > 0 ? AppTheme.PRIMARY : AppTheme.SUCCESS));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.selectedFolderId === item.packageId ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({ width: 1, color: this.selectedFolderId === item.packageId ? AppTheme.PRIMARY : AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${item.directoryName}，${this.folderUsageText(item)}`)
    .onClick(() => this.selectFolder(item));
  }

  @Builder
  private ServerFolderSection() {
    Column({ space: 12 }) {
      Text('选择服务器文件夹')
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索文件夹', text: this.folderKeyword })
          .layoutWeight(1)
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(14)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.folderKeyword = value);
        Button(this.loadingFolders ? '查询中…' : '查询', { type: ButtonType.Normal })
          .height(AppTheme.INPUT_HEIGHT)
          .padding({ left: 14, right: 14 })
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.loadingFolders)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.loadFolders(true); });
      }
      .width('100%');

      Row({ space: 6 }) {
        this.UsageChip('全部', 'ALL');
        this.UsageChip('未使用', 'UNUSED');
        this.UsageChip('已使用', 'USED');
      }
      .width('100%');

      if (this.folders.length === 0 && !this.loadingFolders) {
        Text('没有找到可用的服务器语音文件夹')
          .width('100%')
          .padding({ top: 20, bottom: 20 })
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);
      } else {
        Column({ space: 8 }) {
          ForEach(this.folders, (item: RemoteVoiceFolderItem) => {
            this.FolderCard(item);
          }, (item: RemoteVoiceFolderItem) => item.packageId);
        }
        .width('100%');
      }

      if (this.folderPage + 1 < this.folderTotalPages) {
        Button(this.loadingFolders ? '加载中…' : '加载更多', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.loadingFolders)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.loadFolders(false); });
      }

      if (this.selectedFolder() !== null) {
        Column({ space: 8 }) {
          Text('作业名称')
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          TextInput({
            placeholder: '留空则由系统自动生成',
            text: this.title
          })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(14)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.title = value);
          Text('完成要求由系统统一为“请听语音并结合图片完成任务”。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%')
        .padding(12)
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }
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
        Text('预计用时（分钟）').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
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
        SymbolGlyph(this.messageError ? $r('sys.symbol.exclamationmark_circle_fill') :
          $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17)
          .fontColor([this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS]);
        Text(this.message)
          .layoutWeight(1)
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.messageError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '布置语音作业',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 18 }) {
              this.SourceSelector();
              Divider().color(AppTheme.DIVIDER);

              if (this.sourceMode === VOICE_SOURCE_LOCAL) {
                this.LocalBasicSection();
                Divider().color(AppTheme.DIVIDER);
                this.AudioSection();
                Divider().color(AppTheme.DIVIDER);
                this.ImageSection();
              } else {
                this.ServerFolderSection();
              }

              Divider().color(AppTheme.DIVIDER);
              this.TimingSection();
            }
            .width('100%')
            .padding(AppTheme.PHONE_CARD_PADDING)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);

            this.Feedback();

            Button(this.busy ? '正在发布…' : '发布语音作业', { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.busy)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.createTask(); });
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_REVIEW_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
