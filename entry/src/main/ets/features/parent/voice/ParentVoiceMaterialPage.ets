import {
  VoiceMaterialLocalFile,
  VoiceMaterialLocalPackage
} from '../../../application/assignment/VoiceMaterialDirectoryPicker';
import { RemoteVoiceMaterialPackage } from '../../../application/remote/RemoteVoiceMaterialApi';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  ParentVoiceMaterialViewModel,
  VoiceMaterialLocalValidation
} from './ParentVoiceMaterialViewModel';

const VOICE_SUBJECT_CODES: string[] = ['CHINESE', 'MATH', 'ENGLISH', 'OTHER'];

@Component
export struct ParentVoiceMaterialPage {
  @State private defaultSubjectCode: string = 'CHINESE';
  @State private expectedMinutesText: string = '15';
  @State private pendingPackages: VoiceMaterialLocalPackage[] = [];
  @State private remotePackages: RemoteVoiceMaterialPackage[] = [];
  @State private selecting: boolean = false;
  @State private uploading: boolean = false;
  @State private loading: boolean = false;
  @State private creatingPackageId: string = '';
  @State private message: string = '';
  @State private messageError: boolean = false;

  onBack: () => void = () => {};
  onAssignmentCreated: () => void = () => {};

  private readonly viewModel: ParentVoiceMaterialViewModel =
    new ParentVoiceMaterialViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    void this.reload();
  }

  private expectedMinutes(): number {
    let value = Number(this.expectedMinutesText.trim());
    if (!Number.isFinite(value) || Math.floor(value) !== value || value < 1 || value > 240) return -1;
    return value;
  }

  private async addPackages(): Promise<void> {
    if (this.selecting || this.uploading) return;
    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) {
      this.showError('预计用时请输入 1～240 分钟的整数');
      return;
    }

    this.selecting = true;
    this.clearMessage();
    try {
      let selected = await this.viewModel.selectPackages(
        this.defaultSubjectCode, expectedMinutes);
      if (selected.length === 0) return;
      this.pendingPackages = this.mergePending(this.pendingPackages, selected);
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '选择语音素材目录失败');
    } finally {
      this.selecting = false;
    }
  }

  private mergePending(current: VoiceMaterialLocalPackage[],
    selected: VoiceMaterialLocalPackage[]): VoiceMaterialLocalPackage[] {
    let result: VoiceMaterialLocalPackage[] = current.slice();
    for (let incoming of selected) {
      let index = this.packageIndex(result, incoming.directoryUri);
      if (index < 0) {
        result.push(incoming);
        continue;
      }
      let existing = result[index];
      let files = existing.files.slice();
      for (let file of incoming.files) {
        if (!this.containsFile(files, file.uri)) files.push(file);
      }
      files.sort((left: VoiceMaterialLocalFile, right: VoiceMaterialLocalFile) =>
        left.name.localeCompare(right.name));
      result[index] = {
        directoryUri: existing.directoryUri,
        directoryName: existing.directoryName,
        files: files,
        subjectCode: existing.subjectCode,
        expectedMinutes: existing.expectedMinutes
      };
    }
    result.sort((left: VoiceMaterialLocalPackage, right: VoiceMaterialLocalPackage) =>
      left.directoryName.localeCompare(right.directoryName));
    return result;
  }

  private packageIndex(items: VoiceMaterialLocalPackage[], directoryUri: string): number {
    for (let i = 0; i < items.length; i++) {
      if (items[i].directoryUri === directoryUri) return i;
    }
    return -1;
  }

  private containsFile(files: VoiceMaterialLocalFile[], uri: string): boolean {
    for (let item of files) if (item.uri === uri) return true;
    return false;
  }

  private setPackageSubject(index: number, subjectCode: string): void {
    if (index < 0 || index >= this.pendingPackages.length) return;
    let next = this.pendingPackages.slice();
    let item = next[index];
    next[index] = {
      directoryUri: item.directoryUri,
      directoryName: item.directoryName,
      files: item.files.slice(),
      subjectCode: subjectCode,
      expectedMinutes: item.expectedMinutes
    };
    this.pendingPackages = next;
  }

  private removePackage(index: number): void {
    if (index < 0 || index >= this.pendingPackages.length || this.uploading) return;
    let next: VoiceMaterialLocalPackage[] = [];
    for (let i = 0; i < this.pendingPackages.length; i++) {
      if (i !== index) next.push(this.pendingPackages[i]);
    }
    this.pendingPackages = next;
  }

  private applyDefaultsToPending(): void {
    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) return;
    let next: VoiceMaterialLocalPackage[] = [];
    for (let item of this.pendingPackages) {
      next.push({
        directoryUri: item.directoryUri,
        directoryName: item.directoryName,
        files: item.files.slice(),
        subjectCode: this.defaultSubjectCode,
        expectedMinutes: expectedMinutes
      });
    }
    this.pendingPackages = next;
  }

  private async uploadPending(): Promise<void> {
    if (this.uploading || this.pendingPackages.length === 0) return;
    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) {
      this.showError('预计用时请输入 1～240 分钟的整数');
      return;
    }
    for (let item of this.pendingPackages) {
      let validation = this.viewModel.validate(item);
      if (!validation.valid) {
        this.showError(`${item.directoryName}：${validation.message}`);
        return;
      }
    }

    this.uploading = true;
    this.clearMessage();
    try {
      let batch = await this.viewModel.upload(this.pendingPackages);
      this.pendingPackages = [];
      await this.reload();
      this.showSuccess(`已导入 ${batch.readyCount} 个语音素材目录`);
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '批量导入语音素材失败');
    } finally {
      this.uploading = false;
    }
  }

  private async reload(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    try {
      this.remotePackages = await this.viewModel.list();
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '读取语音素材库失败');
    } finally {
      this.loading = false;
    }
  }

  private async createAssignment(item: RemoteVoiceMaterialPackage): Promise<void> {
    if (this.creatingPackageId.length > 0 || item.status !== 'READY') return;
    this.creatingPackageId = item.id;
    this.clearMessage();
    try {
      let assignment = await this.viewModel.createAssignment(item);
      await this.reload();
      if (assignment !== null) {
        this.showSuccess(`已创建：${assignment.title}`);
        this.onAssignmentCreated();
      } else {
        this.showSuccess('该素材目录已经创建过任务');
      }
    } catch (error) {
      this.showError(error instanceof Error ? error.message : '创建语音任务失败');
    } finally {
      this.creatingPackageId = '';
    }
  }

  private subjectLabel(code: string): string {
    if (code === 'CHINESE') return '语文';
    if (code === 'MATH') return '数学';
    if (code === 'ENGLISH') return '英语';
    return '其他';
  }

  private statusLabel(status: string): string {
    if (status === 'READY') return '待创建';
    if (status === 'CONSUMED') return '已创建';
    if (status === 'INVALID') return '素材异常';
    return '上传中';
  }

  private statusColor(status: string): ResourceColor {
    if (status === 'READY') return AppTheme.PRIMARY;
    if (status === 'CONSUMED') return AppTheme.SUCCESS;
    if (status === 'INVALID') return AppTheme.DANGER;
    return AppTheme.SUBTEXT;
  }

  private statusBackground(status: string): ResourceColor {
    if (status === 'READY') return AppTheme.PRIMARY_SOFT;
    if (status === 'CONSUMED') return AppTheme.SUCCESS_SOFT;
    if (status === 'INVALID') return AppTheme.DANGER_SOFT;
    return AppTheme.SURFACE_SUBTLE;
  }

  private clearMessage(): void {
    this.message = '';
    this.messageError = false;
  }

  private showError(message: string): void {
    this.message = message;
    this.messageError = true;
  }

  private showSuccess(message: string): void {
    this.message = message;
    this.messageError = false;
  }

  @Builder
  private SubjectChip(label: string, code: string, selectedCode: string,
    onSelect: () => void) {
    Button(label, { type: ButtonType.Normal })
      .height(36)
      .padding({ left: 10, right: 10 })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(selectedCode === code ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(selectedCode === code ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(selectedCode === code ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => onSelect());
  }

  @Builder
  private DefaultSettings() {
    Column({ space: 12 }) {
      Text('批量默认设置')
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Column({ space: 7 }) {
        Text('科目').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        Row({ space: 6 }) {
          ForEach(VOICE_SUBJECT_CODES, (code: string) => {
            this.SubjectChip(this.subjectLabel(code), code, this.defaultSubjectCode, () => {
              this.defaultSubjectCode = code;
            });
          }, (code: string) => code);
        }
        .width('100%');
      }
      .width('100%');

      Column({ space: 6 }) {
        Text('预计用时（分钟）').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '15', text: this.expectedMinutesText })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(14)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.expectedMinutesText = value);
      }
      .width('100%');

      if (this.pendingPackages.length > 0) {
        Text('应用到已添加目录')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 6, right: 6 })
          .onClick(() => this.applyDefaultsToPending());
      }
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private PendingPackageCard(item: VoiceMaterialLocalPackage, index: number) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(item.directoryName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          let validation: VoiceMaterialLocalValidation = this.viewModel.validate(item);
          Text(`${validation.audioCount} 个语音 · ${validation.imageCount} 张图片 · ${validation.message}`)
            .fontSize(12)
            .fontColor(validation.valid ? AppTheme.SUBTEXT : AppTheme.DANGER);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('移除')
          .fontSize(12)
          .fontColor(AppTheme.DANGER)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 4 })
          .onClick(() => this.removePackage(index));
      }
      .width('100%');

      Row({ space: 6 }) {
        Text('科目').fontSize(12).fontColor(AppTheme.SUBTEXT);
        ForEach(VOICE_SUBJECT_CODES, (code: string) => {
          this.SubjectChip(this.subjectLabel(code), code, item.subjectCode, () => {
            this.setPackageSubject(index, code);
          });
        }, (code: string) => `${item.directoryUri}-${code}`);
      }
      .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private PendingSection() {
    Column({ space: 10 }) {
      Row() {
        Text('待导入目录')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.pendingPackages.length} 个`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Button(this.selecting ? '正在打开文件选择器…' : '＋ 添加目录', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .enabled(!this.selecting && !this.uploading)
        .onClick(() => { void this.addPackages(); });

      Text('支持目录选择的设备可直接多选文件夹；其他设备可选择目录内的语音和图片，系统会按父目录自动归组。')
        .width('100%')
        .fontSize(11)
        .lineHeight(17)
        .fontColor(AppTheme.SUBTEXT);

      ForEach(this.pendingPackages, (item: VoiceMaterialLocalPackage, index: number) => {
        this.PendingPackageCard(item, index);
      }, (item: VoiceMaterialLocalPackage) => item.directoryUri);

      if (this.pendingPackages.length > 0) {
        Button(this.uploading ? '正在导入…' : `导入 ${this.pendingPackages.length} 个目录`,
          { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.uploading)
          .onClick(() => { void this.uploadPending(); });
      }
    }
    .width('100%');
  }

  @Builder
  private RemotePackageCard(item: RemoteVoiceMaterialPackage) {
    Column({ space: 9 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(item.directoryName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(`${this.subjectLabel(item.subjectCode)} · ${item.expectedMinutes} 分钟 · ${item.files.length} 个文件`)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(this.statusLabel(item.status))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item.status))
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.statusBackground(item.status))
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%');

      if (item.status === 'INVALID' && item.errorMessage.length > 0) {
        Text(item.errorMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.DANGER);
      }

      if (item.status === 'READY') {
        Button(this.creatingPackageId === item.id ? '正在创建…' : '创建语音任务',
          { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .enabled(this.creatingPackageId.length === 0)
          .onClick(() => { void this.createAssignment(item); });
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private LibrarySection() {
    Column({ space: 10 }) {
      Row() {
        Text('语音素材库')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(this.loading ? '刷新中…' : `${this.remotePackages.length} 个目录`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.remotePackages.length === 0 && !this.loading) {
        Text('还没有语音素材。导入后，学生每天首次检查时最多自动创建 1 个任务。')
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);
      } else {
        ForEach(this.remotePackages, (item: RemoteVoiceMaterialPackage) => {
          this.RemotePackageCard(item);
        }, (item: RemoteVoiceMaterialPackage) => `${item.id}-${item.status}`);
      }
    }
    .width('100%');
  }

  @Builder
  private Feedback() {
    if (this.message.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.messageError ?
          $r('sys.symbol.exclamationmark_circle_fill') : $r('sys.symbol.checkmark_circle_fill'))
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
          title: '语音素材库',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: AppTheme.PHONE_SECTION_GAP }) {
            this.DefaultSettings();
            this.PendingSection();
            this.Feedback();
            Divider().color(AppTheme.DIVIDER);
            this.LibrarySection();
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
