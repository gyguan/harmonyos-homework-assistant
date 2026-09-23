import {
  VoiceMaterialLocalFile,
  VoiceMaterialLocalPackage
} from '../../../application/assignment/VoiceMaterialDirectoryPicker';
import {
  RemoteVoiceMaterialPackage,
  RemoteVoiceMaterialCreateAssignmentRequest
} from '../../../application/remote/RemoteVoiceMaterialApi';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { ParentVoiceMaterialViewModel } from './ParentVoiceMaterialViewModel';

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
  @State private createPackageId: string = '';
  @State private createStudentId: string = '';
  @State private createDueOption: string = 'TODAY';
  @State private createCustomDueDate: string = '';
  @State private createMinutesText: string = '15';
  @State private creatingAssignment: boolean = false;
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

  private setPackageExpectedMinutes(index: number, value: string): void {
    if (index < 0 || index >= this.pendingPackages.length) return;
    let minutes = Number(value.trim());
    if (!Number.isFinite(minutes) || Math.floor(minutes) !== minutes || minutes < 1 || minutes > 240) return;
    let next = this.pendingPackages.slice();
    let item = next[index];
    next[index] = {
      directoryUri: item.directoryUri,
      directoryName: item.directoryName,
      files: item.files.slice(),
      subjectCode: item.subjectCode,
      expectedMinutes: minutes
    };
    this.pendingPackages = next;
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
      let result = await this.viewModel.upload(this.pendingPackages);
      this.pendingPackages = [];
      await this.reload();
      let failedCount = result.batch.invalidCount + result.registrationFailureCount;
      if (failedCount > 0) {
        this.showSuccess(`已导入 ${result.batch.readyCount} 个，${failedCount} 个目录未成功`);
      } else {
        this.showSuccess(`已导入 ${result.batch.readyCount} 个语音素材目录`);
      }
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

  private openCreateSheet(item: RemoteVoiceMaterialPackage): void {
    if (this.creatingAssignment || item.hasActiveAssignment ||
      (item.status !== 'READY' && item.status !== 'CONSUMED')) return;
    this.createPackageId = item.id;
    this.createStudentId = item.studentId;
    this.createDueOption = 'TODAY';
    this.createCustomDueDate = '';
    this.createMinutesText = `${item.expectedMinutes || 15}`;
    this.clearMessage();
  }

  private closeCreateSheet(): void {
    if (this.creatingAssignment) return;
    this.createPackageId = '';
  }

  private creatingItem(): RemoteVoiceMaterialPackage | null {
    for (let item of this.remotePackages) if (item.id === this.createPackageId) return item;
    return null;
  }

  private createDue(): { epochMs: number; text: string } | null {
    let now = new Date();
    let base = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    if (this.createDueOption === 'TODAY') return { epochMs: base.getTime(), text: '今天' };
    if (this.createDueOption === 'TOMORROW') return { epochMs: base.getTime() + 24 * 60 * 60 * 1000, text: '明天' };
    if (this.createDueOption === 'THREE_DAYS') return { epochMs: base.getTime() + 3 * 24 * 60 * 60 * 1000, text: '3天后' };
    let value = this.createCustomDueDate.trim();
    if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(value)) return null;
    let timestamp = Date.parse(value + 'T23:59:59');
    if (!Number.isFinite(timestamp) || timestamp < base.getTime()) return null;
    return { epochMs: timestamp, text: '自定义' };
  }

  private async confirmCreateAssignment(): Promise<void> {
    let item = this.creatingItem();
    if (item === null || this.creatingAssignment) return;
    let minutes = Number(this.createMinutesText.trim());
    if (!Number.isInteger(minutes) || minutes < 1 || minutes > 240) {
      this.showError('预计时长请输入 1～240 分钟的整数');
      return;
    }
    let due = this.createDue();
    if (due === null) {
      this.showError('请选择有效的截止日期');
      return;
    }
    this.creatingAssignment = true;
    this.creatingPackageId = item.id;
    this.clearMessage();
    try {
      let request: RemoteVoiceMaterialCreateAssignmentRequest = {
        studentId: this.createStudentId,
        expectedMinutes: minutes,
        dueAtEpochMs: due.epochMs,
        dueText: due.text
      };
      let assignment = await this.viewModel.createAssignment(item, request);
      await this.reload();
      this.createPackageId = '';
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
      this.creatingAssignment = false;
    }
  }

  private subjectLabel(code: string): string {
    if (code === 'CHINESE') return '语文';
    if (code === 'MATH') return '数学';
    if (code === 'ENGLISH') return '英语';
    return '其他';
  }

  private statusLabel(item: RemoteVoiceMaterialPackage): string {
    if (item.hasActiveAssignment) return '已有任务';
    if (item.hasCreatedBefore) return '已创建过';
    if (item.status === 'READY') return '待创建';
    if (item.status === 'INVALID') return '素材异常';
    return '上传中';
  }

  private statusColor(item: RemoteVoiceMaterialPackage): string {
    if (item.hasActiveAssignment) return AppTheme.SUCCESS;
    if (item.hasCreatedBefore) return AppTheme.PRIMARY;
    if (item.status === 'READY') return AppTheme.PRIMARY;
    if (item.status === 'INVALID') return AppTheme.DANGER;
    return AppTheme.SUBTEXT;
  }

  private statusBackground(item: RemoteVoiceMaterialPackage): string {
    if (item.hasActiveAssignment) return AppTheme.SUCCESS_SOFT;
    if (item.hasCreatedBefore) return AppTheme.PRIMARY_SOFT;
    if (item.status === 'READY') return AppTheme.PRIMARY_SOFT;
    if (item.status === 'INVALID') return AppTheme.DANGER_SOFT;
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

  private validationSummary(item: VoiceMaterialLocalPackage): string {
    let validation = this.viewModel.validate(item);
    return `${validation.audioCount} 个语音 · ${validation.imageCount} 张图片 · ${validation.message}`;
  }

  private validationColor(item: VoiceMaterialLocalPackage): string {
    return this.viewModel.validate(item).valid ? AppTheme.SUBTEXT : AppTheme.DANGER;
  }

  @Builder
  private DefaultSubjectChip(label: string, code: string) {
    Button(label, { type: ButtonType.Normal })
      .height(36)
      .padding({ left: 10, right: 10 })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(12)
      .fontWeight(this.defaultSubjectCode === code ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.defaultSubjectCode === code ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.defaultSubjectCode === code ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => {
        this.defaultSubjectCode = code;
      });
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
          this.DefaultSubjectChip('语文', 'CHINESE');
          this.DefaultSubjectChip('数学', 'MATH');
          this.DefaultSubjectChip('英语', 'ENGLISH');
          this.DefaultSubjectChip('其他', 'OTHER');
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
          Text(this.validationSummary(item))
            .fontSize(12)
            .fontColor(this.validationColor(item));
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

      Row({ space: 8 }) {
        Text('预计用时').fontSize(12).fontColor(AppTheme.SUBTEXT);
        TextInput({ text: `${item.expectedMinutes}` })
          .width(92)
          .height(38)
          .fontSize(13)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CHIP_RADIUS)
          .onChange((value: string) => this.setPackageExpectedMinutes(index, value));
        Text('分钟').fontSize(12).fontColor(AppTheme.SUBTEXT);
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

      Text('支持目录选择的设备可直接选择文件夹；如需批量导入，可重复点击“添加目录”。不支持目录选择的设备可选择目录内的语音和图片，系统会按父目录自动归组。')
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

        Text(this.statusLabel(item))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item))
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.statusBackground(item))
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%');

      if (item.status === 'INVALID' && item.errorMessage.length > 0) {
        Text(item.errorMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.DANGER);
      }

      if (item.status === 'READY' || item.status === 'CONSUMED') {
        Button(
          this.creatingPackageId === item.id
            ? '正在创建…'
            : item.hasActiveAssignment
              ? '已有任务'
              : item.hasCreatedBefore
                ? '再次创建任务'
                : '创建语音任务',
          { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .enabled(this.creatingPackageId.length === 0 && !item.hasActiveAssignment)
          .onClick(() => this.openCreateSheet(item));
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private CreateAssignmentSheet() {
    let item = this.creatingItem();
    if (item !== null) {
      Column() {
        Blank().layoutWeight(1).onClick(() => this.closeCreateSheet());
        Column({ space: 14 }) {
          Row() {
            Text('创建语音任务').fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Blank();
            Text('关闭').fontSize(13).fontColor(AppTheme.SUBTEXT).onClick(() => this.closeCreateSheet());
          }.width('100%');
          Text(item.directoryName).width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('学生').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Row({ space: 8 }) {
            ForEach(this.viewModel.students(), (student: StudentProfile) => {
              this.SubjectChip(student.name, student.id, this.createStudentId, () => {
                this.createStudentId = student.id;
              });
            }, (student: StudentProfile) => 'create-' + student.id);
          }.width('100%');
          Text('截止时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Row({ space: 6 }) {
            this.SubjectChip('今天', 'TODAY', this.createDueOption, () => this.createDueOption = 'TODAY');
            this.SubjectChip('明天', 'TOMORROW', this.createDueOption, () => this.createDueOption = 'TOMORROW');
            this.SubjectChip('3天后', 'THREE_DAYS', this.createDueOption, () => this.createDueOption = 'THREE_DAYS');
            this.SubjectChip('自定义', 'CUSTOM', this.createDueOption, () => this.createDueOption = 'CUSTOM');
          }.width('100%');
          if (this.createDueOption === 'CUSTOM') {
            TextInput({ placeholder: 'YYYY-MM-DD', text: this.createCustomDueDate })
              .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(14)
              .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
              .onChange((value: string) => this.createCustomDueDate = value);
          }
          Text('预计时长（分钟）').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          TextInput({ text: this.createMinutesText })
            .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(14)
            .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.createMinutesText = value);
          Row({ space: 10 }) {
            Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
              .backgroundColor(AppTheme.SURFACE_SUBTLE).fontColor(AppTheme.TEXT).borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.creatingAssignment).onClick(() => this.closeCreateSheet());
            Button(this.creatingAssignment ? '创建中…' : '确认创建', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.BUTTON_HEIGHT)
              .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY).borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.creatingAssignment).onClick(() => { void this.confirmCreateAssignment(); });
          }.width('100%');
        }
        .width('100%').padding(AppTheme.PHONE_CARD_PADDING).backgroundColor(AppTheme.SURFACE)
        .borderRadius({ topLeft: 20, topRight: 20 });
      }
      .width('100%').height('100%').backgroundColor('#66000000');
    }
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
        Text(this.messageError ? '!' : '✓')
          .width(20)
          .height(20)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS)
          .textAlign(TextAlign.Center);
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
    Stack({ alignContent: Alignment.Bottom }) {
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
      if (this.createPackageId.length > 0) {
        this.CreateAssignmentSheet();
      }
    }
    .width('100%')
    .height('100%');
  }
}
