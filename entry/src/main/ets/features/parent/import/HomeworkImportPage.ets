import { HomeworkStudentTeacherRemoteApi, HomeworkTeacherOption } from '../../../application/remote/HomeworkStudentTeacherRemoteApi';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { Subject } from '../../../domain/model/HomeworkModels';
import { ChoiceSelectionChip, SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import { PhotoPreviewDialog } from '../../../components/submission/PhotoPreviewDialog';
import { HomeworkImportViewModel } from './HomeworkImportViewModel';

enum HomeworkAssignmentInputMode {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE'
}

@Component
export struct HomeworkImportPage {
  @Prop revision: number = 0;
  @Prop embeddedInDeepPage: boolean = false;
  @State private localRevision: number = 0;
  @State private parseBusy: boolean = false;
  @State private busyHint: string = '';
  @State private parseMessage: string = '';
  @State private parseError: boolean = false;
  @State private textDraft: string = '';
  @State private sourceImageRef: string = '';
  @State private sourceImageLabel: string = '';
  @State private selectedSubject: Subject | null = null;
  @State private subjectOptionsOpen: boolean = false;
  @State private inputMode: HomeworkAssignmentInputMode = HomeworkAssignmentInputMode.TEXT;
  @State private boundTeacherName: string = '';
  @State private teacherDraft: string = '';
  @State private teacherOptions: HomeworkTeacherOption[] = [];
  @State private teacherBusy: boolean = false;
  @State private teacherError: string = '';
  private teacherStudentId: string = '';
  @State private previewImageUri: string = '';
  private previewController: CustomDialogController = new CustomDialogController({
    builder: PhotoPreviewDialog({ uri: $previewImageUri }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });
  onOpenConfirmation: () => void = () => {};
  onOpenRecords: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkImportViewModel = new HomeworkImportViewModel();

  aboutToAppear(): void {
    this.resetInputDraft();
    void this.loadTeachers();
  }

  private async loadTeachers(): Promise<void> {
    let studentId = this.viewModel.activeStudentId();
    if (studentId.length === 0) return;
    if (this.teacherStudentId !== studentId) {
      this.teacherStudentId = studentId;
      this.boundTeacherName = '';
      this.teacherDraft = '';
      this.teacherOptions = [];
    }
    this.teacherBusy = true;
    try {
      let loaded = await HomeworkStudentTeacherRemoteApi.instance.list(studentId);
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.teacherOptions = loaded;
      this.teacherError = '';
    } catch {
      if (studentId === this.viewModel.activeStudentId()) {
        this.teacherError = '老师列表加载失败，仍可不指定老师进行整理';
      }
    } finally {
      this.teacherBusy = false;
    }
  }

  private async saveTeacher(): Promise<void> {
    let studentId = this.viewModel.activeStudentId();
    let name = this.teacherDraft.trim();
    if (name.length < 2) {
      this.teacherError = '请输入完整老师姓名或称呼';
      return;
    }
    this.teacherBusy = true;
    try {
      let saved = await HomeworkStudentTeacherRemoteApi.instance.register(
        studentId, name, this.selectedSubject === null ? Subject.OTHER : this.selectedSubject);
      if (studentId !== this.viewModel.activeStudentId()) return;
      let next = this.teacherOptions.filter((item: HomeworkTeacherOption) =>
        item.id !== saved.id);
      next.unshift(saved);
      this.teacherOptions = next;
      this.boundTeacherName = saved.teacherName;
      this.teacherDraft = '';
      this.teacherError = '';
    } catch {
      if (studentId === this.viewModel.activeStudentId()) this.teacherError = '保存老师失败，请检查后端连接';
    } finally {
      this.teacherBusy = false;
    }
  }

  private touchRevision(): number {
    return this.revision + this.localRevision;
  }

  private pendingCandidateCount(): number {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return 0;
    return this.viewModel.candidates().length;
  }

  private resetInputDraft(): void {
    this.inputMode = HomeworkAssignmentInputMode.TEXT;
    this.textDraft = '';
    this.sourceImageRef = '';
    this.sourceImageLabel = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  private afterOrganized(candidateCount: number): void {
    this.localRevision++;
    this.onStoreChanged();
    if (candidateCount > 0) this.onOpenConfirmation();
  }

  private usesImageAiParse(): boolean {
    return this.inputMode === HomeworkAssignmentInputMode.IMAGE && this.sourceImageRef.length > 0;
  }

  private async organize(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    if (studentId !== this.teacherStudentId) {
      this.teacherStudentId = studentId;
      this.boundTeacherName = '';
      this.teacherOptions = [];
      void this.loadTeachers();
    }
    let text = this.textDraft.trim();
    if (this.inputMode === HomeworkAssignmentInputMode.TEXT && text.length === 0) {
      this.showParseError('请输入作业文字');
      return;
    }
    if (this.inputMode === HomeworkAssignmentInputMode.IMAGE && this.sourceImageRef.length === 0) {
      this.showParseError('请先拍照或选择作业图片');
      return;
    }

    this.parseBusy = true;
    this.busyHint = this.usesImageAiParse() ? '正在识别图片中的作业，约 3–8 秒，请稍候' : '正在整理作业内容…';
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkTextImportResult;
      if (this.inputMode === HomeworkAssignmentInputMode.IMAGE) {
        result = await this.viewModel.parseImage(
          this.sourceImageRef, this.selectedSubject, this.sourceImageLabel, '', this.boundTeacherName);
      } else {
        result = await this.viewModel.parseText(text, this.selectedSubject, '', '', this.boundTeacherName);
      }
      if (studentId !== this.viewModel.activeStudentId()) return;
      if (result.candidateCount > 0) {
        if (result.aiFailed) {
          // AI 整理失败后拿到的是降级结果，准确度有折扣：留在当前页把提示读清楚，
          // 由用户自己点「继续核对」，别把降级结果直接推进发布流程。
          this.parseMessage = `AI 整理失败，已用简化方式整理出 ${result.candidateCount} 项作业，请逐项核对后再发布`;
          this.parseError = true;
          this.localRevision++;
          this.onStoreChanged();
          return;
        }
        this.parseMessage = `已整理出 ${result.candidateCount} 项作业，请继续核对`;
        this.afterOrganized(result.candidateCount);
      } else {
        this.showParseError(this.inputMode === HomeworkAssignmentInputMode.IMAGE ?
          '没有整理出作业，请换一张图片后重试' : '没有整理出作业，请核对文字内容后重试');
      }
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '作业整理失败，请稍后重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private async recognizePhoto(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    this.parseBusy = true;
    this.busyHint = '正在读取照片…';
    this.parseMessage = '';
    this.parseError = false;
    try {
      let imageRef = await this.viewModel.captureImage();
      if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '现场拍照');
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '拍照识别失败，请重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private async recognizeGallery(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    this.parseBusy = true;
    this.busyHint = '正在读取图片…';
    this.parseMessage = '';
    this.parseError = false;
    try {
      let imageRef = await this.viewModel.selectImage();
      if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '相册作业图片');
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '图片识别失败，请重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private showParseError(message: string): void {
    this.parseMessage = message;
    this.parseError = true;
  }

  private applySelectedImage(imageRef: string, sourceLabel: string): void {
    if (imageRef.length === 0) return;
    this.inputMode = HomeworkAssignmentInputMode.IMAGE;
    this.textDraft = '';
    this.sourceImageRef = imageRef;
    this.sourceImageLabel = sourceLabel;
    this.parseMessage = '';
    this.parseError = false;
  }

  private selectInputMode(mode: HomeworkAssignmentInputMode): void {
    if (this.parseBusy || this.inputMode === mode) return;
    this.inputMode = mode;
    if (mode === HomeworkAssignmentInputMode.TEXT) {
      this.sourceImageRef = '';
      this.sourceImageLabel = '';
    } else {
      this.textDraft = '';
    }
    this.parseMessage = '';
    this.parseError = false;
  }

  private selectSubject(subject: Subject | null): void {
    if (this.parseBusy) return;
    this.selectedSubject = subject;
    this.parseMessage = '';
    this.parseError = false;
  }

  private clearAssignmentText(): void {
    if (this.parseBusy) return;
    this.textDraft = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  private openImagePreview(uri: string): void {
    if (uri.length === 0) return;
    this.previewImageUri = uri;
    this.previewController.open();
  }

  private removeSourceImage(): void {
    if (this.parseBusy) return;
    this.sourceImageRef = '';
    this.sourceImageLabel = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  @Builder
  private SubjectSelector() {
    Flex({ wrap: FlexWrap.Wrap }) {
      Row() {
        ChoiceSelectionChip({
          label: '自动识别',
          selected: this.selectedSubject === null,
          onSelect: () => this.selectSubject(null)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.CHINESE,
          selected: this.selectedSubject === Subject.CHINESE,
          onSelect: () => this.selectSubject(Subject.CHINESE)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.MATH,
          selected: this.selectedSubject === Subject.MATH,
          onSelect: () => this.selectSubject(Subject.MATH)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.ENGLISH,
          selected: this.selectedSubject === Subject.ENGLISH,
          onSelect: () => this.selectSubject(Subject.ENGLISH)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.OTHER,
          selected: this.selectedSubject === Subject.OTHER,
          onSelect: () => this.selectSubject(Subject.OTHER)
        });
      }
      .margin({ right: 8, bottom: 8 });
    }
    .width('100%')
    .enabled(!this.parseBusy);
  }

  @Builder
  private SubjectOptions() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('科目（可选）')
          .layoutWeight(1)
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.selectedSubject === null ? '自动识别' : this.selectedSubject)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(this.selectedSubject === null ? AppTheme.SUBTEXT : AppTheme.PRIMARY);
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(AppTheme.META_SIZE)
          .fontColor([AppTheme.TERTIARY_TEXT])
          .rotate({ angle: this.subjectOptionsOpen ? 90 : 0 });
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .enabled(!this.parseBusy)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(`科目：${this.selectedSubject === null ? '自动识别' : this.selectedSubject}，${this.subjectOptionsOpen ? '收起' : '展开'}科目设置`)
      .onClick(() => {
        if (!this.parseBusy) this.subjectOptionsOpen = !this.subjectOptionsOpen;
      });
      if (this.subjectOptionsOpen) {
        this.SubjectSelector();
      }
      Text(this.selectedSubject === null ? '按每项作业自动识别，支持一张图片包含多个科目' :
        '本次所有作业将使用所选科目')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private FeedbackBanner() {
    if (this.parseMessage.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.parseError ? $r('sys.symbol.exclamationmark_circle_fill') :
          $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17)
          .fontColor([this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS]);
        Text(this.parseMessage)
          .layoutWeight(1)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.parseError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private BusyBanner() {
    if (this.parseBusy) {
      Row({ space: 10 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(AppTheme.PRIMARY);
        Column({ space: 2 }) {
          Text(this.busyHint.length > 0 ? this.busyHint : '正在处理，请稍候')
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('请保持页面停留，完成后可继续核对')
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding(10)
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityText(`处理中：${this.busyHint.length > 0 ? this.busyHint : '正在处理，请稍候'}`);
    }
  }

  @Builder
  private PendingReview() {
    if (this.pendingCandidateCount() > 0) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(`已有 ${this.pendingCandidateCount()} 项待发布作业`)
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
            .fontColor(AppTheme.TEXT);
          Text('继续上次的核对与发布')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('继续核对')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(AppTheme.CARD_SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('继续核对待发布作业')
      .enabled(!this.parseBusy)
      .onClick(() => this.onOpenConfirmation());
    }
  }

  @Builder
  private ImportRecordsEntry() {
    Row({ space: 6 }) {
      Text('导入记录')
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([AppTheme.SUBTEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('查看历史导入记录')
    .enabled(!this.parseBusy)
    .onClick(() => this.onOpenRecords());
  }

  @Builder
  private RecognitionActions() {
    Row({ space: 8 }) {
      Button('拍照', { type: ButtonType.Normal })
        .layoutWeight(1)
        .constraintSize({ minHeight: AppTheme.SECONDARY_BUTTON_HEIGHT })
        .padding({ top: 10, bottom: 10 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontColor(AppTheme.TEXT)
        .fontWeight(FontWeight.Medium)
        .accessibilityText('拍照添加作业图片')
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizePhoto(); });

      Button('选图片', { type: ButtonType.Normal })
        .layoutWeight(1)
        .constraintSize({ minHeight: AppTheme.SECONDARY_BUTTON_HEIGHT })
        .padding({ top: 10, bottom: 10 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontColor(AppTheme.TEXT)
        .fontWeight(FontWeight.Medium)
        .accessibilityText('从相册添加作业图片')
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizeGallery(); });
    }
    .width('100%');
  }

  private canOrganize(): boolean {
    if (this.parseBusy) return false;
    if (this.inputMode === HomeworkAssignmentInputMode.IMAGE) return this.sourceImageRef.length > 0;
    return this.textDraft.trim().length > 0;
  }

  @Builder
  private ImageInput() {
    if (this.sourceImageRef.length > 0) {
      Row({ space: 8 }) {
        Text('已添加作业图片')
          .layoutWeight(1)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
        Text('移除图片')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.PRIMARY)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('移除作业图片')
          .enabled(!this.parseBusy)
          .onClick(() => this.removeSourceImage());
      }
      .width('100%');
      Image(this.sourceImageRef)
        .width('100%')
        .height(200)
        .objectFit(ImageFit.Contain)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('全屏查看已添加作业图片')
        .onClick(() => this.openImagePreview(this.sourceImageRef));
      Text('图片将直接交给 AI 解析，不再与文字混合提交')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);

    }
  }

  @Builder
  private InputModeSelector() {
    Column({ space: 8 }) {
      Text('输入方式')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '文字输入',
          selected: this.inputMode === HomeworkAssignmentInputMode.TEXT,
          onSelect: () => this.selectInputMode(HomeworkAssignmentInputMode.TEXT)
        });
        SegmentedSelectionButton({
          label: '图片上传',
          selected: this.inputMode === HomeworkAssignmentInputMode.IMAGE,
          onSelect: () => this.selectInputMode(HomeworkAssignmentInputMode.IMAGE)
        });
      }
      .width('100%');
      Text(this.inputMode === HomeworkAssignmentInputMode.TEXT ?
        '直接录入老师布置的作业文字' : '拍照或从相册选择一张作业图片')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%');
  }

  @Builder
  private TeacherSelector() {
    Column({ space: 8 }) {
      Text('来源老师（选填）')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.TEXT);
      Text('指定老师后，仅参考当前孩子这位老师的经验；无法确定时可以不选。')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 6 }) {
        ChoiceSelectionChip({
          label: '不指定',
          selected: this.boundTeacherName.length === 0,
          compact: true,
          onSelect: () => this.boundTeacherName = ''
        });
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.teacherOptions, (teacher: HomeworkTeacherOption) => {
              ChoiceSelectionChip({
                label: `${teacher.teacherName} · ${teacher.subject}`,
                selected: this.boundTeacherName === teacher.teacherName,
                compact: true,
                onSelect: () => this.boundTeacherName = teacher.teacherName
              });
            }, (teacher: HomeworkTeacherOption) => teacher.id);
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1);
      }
      .width('100%');
      Row({ space: 8 }) {
        TextInput({ text: this.teacherDraft, placeholder: '新增老师，例如 王老师' })
          .layoutWeight(1)
          .height(AppTheme.INPUT_HEIGHT)
          .onChange((value: string) => this.teacherDraft = value);
        Button(this.teacherBusy ? '保存中' : '保存老师', { type: ButtonType.Normal })
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.PRIMARY)
          .enabled(!this.teacherBusy && !this.parseBusy)
          .onClick(() => { void this.saveTeacher(); });
      }
      .width('100%');
      if (this.teacherError.length > 0) {
        Text(this.teacherError)
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%');
  }

  @Builder
  private AssignmentInput() {
    Column({ space: 12 }) {
      Text('作业内容')
        .width('100%')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      this.InputModeSelector();
      this.TeacherSelector();
      if (this.inputMode === HomeworkAssignmentInputMode.IMAGE) {
        this.RecognitionActions();
        this.ImageInput();
      } else {
        Row({ space: 8 }) {
          Text('作业文字')
            .layoutWeight(1)
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
          if (this.textDraft.length > 0) {
            Text('清空文字')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空作业文字')
              .enabled(!this.parseBusy)
              .onClick(() => this.clearAssignmentText());
          }
        }
        .width('100%');
        TextArea({
          placeholder: '例如：语文背诵第12课；数学完成口算练习',
          text: this.textDraft
        })
          .width('100%')
          .height(160)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .lineHeight(AppTheme.FORM_TEXT_LINE_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.parseBusy)
          .onChange((value: string) => {
            this.textDraft = value;
            this.parseMessage = '';
            this.parseError = false;
          });
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private ActionFooter() {
    Column({ space: 8 }) {
      this.BusyBanner();
      this.FeedbackBanner();

      Button(this.parseBusy ? (this.usesImageAiParse() ? '正在识别图片…' : '正在处理…') : '整理并继续',
        { type: ButtonType.Normal })
        .width('100%')
        .constraintSize({ minHeight: AppTheme.BUTTON_HEIGHT })
        .padding({ top: 12, bottom: 12 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.canOrganize())
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.canOrganize() ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.organize(); });
      Text('下一步核对作业，确认后再发布')
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(AppTheme.BACKGROUND);
  }

  build() {
    Column() {
      if (!this.embeddedInDeepPage) {
        Text('布置作业')
          .width('100%')
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .margin({ bottom: 12 });
      }

      Scroll() {
        Column({ space: AppTheme.ITEM_GAP }) {
          this.AssignmentInput();
          this.SubjectOptions();
          this.PendingReview();
          this.ImportRecordsEntry();
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ bottom: 8 });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      this.ActionFooter();
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
    .padding({
      left: this.embeddedInDeepPage ? 0 : AppTheme.PAGE_PADDING_COMPACT,
      right: this.embeddedInDeepPage ? 0 : AppTheme.PAGE_PADDING_COMPACT,
      top: this.embeddedInDeepPage ? 0 : 14
    })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
