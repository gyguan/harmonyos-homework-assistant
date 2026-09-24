import { SelectionIds } from '../../../common/state/SelectionIds';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';
import { HomeworkConfirmationViewModel } from './HomeworkConfirmationViewModel';
import { ConfirmationCandidateCard, ConfirmationCandidateEditor } from './ConfirmationCandidateComponents';

@Component
export struct HomeworkConfirmationPage {
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private editingCandidateId: string = '';
  @State private manualCandidateDraft: CandidateAssignment | null = null;
  @State private pendingDeleteCandidateId: string = '';
  @State private showEditorSheet: boolean = false;
  @State private publishing: boolean = false;
  @State private publishMessage: string = '';
  @State private publishError: boolean = false;
  @State private bulkMode: boolean = false;
  @State private selectedCandidateIds: string[] = [];
  @State private batchDeleteConfirm: boolean = false;
  onBack: () => void = () => {};
  onPublished: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkConfirmationViewModel = new HomeworkConfirmationViewModel();

  private touchRevision(): number { return this.revision + this.localRevision; }

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.candidates();
  }

  private editingCandidate(): CandidateAssignment | null {
    if (this.manualCandidateDraft !== null && this.manualCandidateDraft.id === this.editingCandidateId) {
      return this.manualCandidateDraft;
    }
    for (let item of this.candidates()) if (item.id === this.editingCandidateId) return item;
    return null;
  }

  private candidateRenderKey(item: CandidateAssignment): string {
    return `${item.id}|${item.subject}|${item.title}|${item.instruction}|${item.dueText}|${item.textbookRef}|${item.expectedMinutes}`;
  }

  private openEditor(candidateId: string): void {
    if (this.bulkMode) return;
    this.editingCandidateId = candidateId;
    this.showEditorSheet = true;
  }

  private closeEditor(): void {
    this.showEditorSheet = false;
  }

  private completeEditorDismiss(): void {
    let pendingDeleteCandidateId = this.pendingDeleteCandidateId;
    this.editingCandidateId = '';
    this.manualCandidateDraft = null;
    this.pendingDeleteCandidateId = '';
    if (pendingDeleteCandidateId.length > 0) this.commitCandidateRemoval(pendingDeleteCandidateId);
  }

  private saveCandidate(candidate: CandidateAssignment): boolean {
    let saved = this.manualCandidateDraft !== null && this.manualCandidateDraft.id === candidate.id ?
      this.viewModel.addCandidate(candidate) : this.viewModel.updateCandidate(candidate);
    if (!saved) return false;
    this.localRevision++;
    this.onStoreChanged();
    return true;
  }

  private setExpectedMinutes(item: CandidateAssignment, minutes: number): void {
    if (this.bulkMode) return;
    this.saveCandidate({
      id: item.id,
      studentId: item.studentId,
      subject: item.subject,
      title: item.title,
      instruction: item.instruction,
      textbookRef: item.textbookRef,
      dueText: item.dueText,
      expectedMinutes: minutes,
      sourceEvidence: {
        sourceLabel: item.sourceEvidence.sourceLabel,
        excerpt: item.sourceEvidence.excerpt,
        batchId: item.sourceEvidence.batchId,
        sourceType: item.sourceEvidence.sourceType,
        sourceMessageIds: item.sourceEvidence.sourceMessageIds === undefined ?
          undefined : item.sourceEvidence.sourceMessageIds.slice(),
        rawText: item.sourceEvidence.rawText,
        imageRef: item.sourceEvidence.imageRef,
        capturedAtEpochMs: item.sourceEvidence.capturedAtEpochMs
      },
      confidence: item.confidence
    });
  }

  private addCandidate(): void {
    if (this.bulkMode) return;
    let candidate = this.viewModel.createManualCandidateDraft();
    this.manualCandidateDraft = candidate;
    this.editingCandidateId = candidate.id;
    this.showEditorSheet = true;
  }

  private removeCandidate(candidateId: string): void {
    if (this.manualCandidateDraft !== null && this.manualCandidateDraft.id === candidateId) {
      this.closeEditor();
      return;
    }
    this.pendingDeleteCandidateId = candidateId;
    this.closeEditor();
  }

  private commitCandidateRemoval(candidateId: string): void {
    if (!this.viewModel.removeCandidate(candidateId)) return;
    this.selectedCandidateIds = SelectionIds.without(this.selectedCandidateIds, candidateId);
    this.localRevision++;
    if (this.candidates().length === 0) this.exitBulkMode();
    this.onStoreChanged();
  }

  private isCandidateSelected(candidateId: string): boolean {
    return SelectionIds.contains(this.selectedCandidateIds, candidateId);
  }

  private toggleCandidateSelection(candidateId: string): void {
    if (!this.bulkMode) return;
    this.selectedCandidateIds = SelectionIds.toggle(this.selectedCandidateIds, candidateId);
    this.batchDeleteConfirm = false;
  }

  private enterBulkMode(): void {
    if (this.candidates().length === 0) return;
    this.bulkMode = true;
    this.selectedCandidateIds = [];
    this.batchDeleteConfirm = false;
  }

  private exitBulkMode(): void {
    this.bulkMode = false;
    this.selectedCandidateIds = [];
    this.batchDeleteConfirm = false;
  }

  private selectAllCandidates(): void {
    let ids: string[] = [];
    for (let item of this.candidates()) ids.push(item.id);
    this.selectedCandidateIds = ids;
    this.batchDeleteConfirm = false;
  }

  private removeSelectedCandidates(): void {
    if (this.selectedCandidateIds.length === 0) return;
    let ids = SelectionIds.copy(this.selectedCandidateIds);
    let removed = 0;
    for (let id of ids) {
      if (this.viewModel.removeCandidate(id)) removed++;
    }
    if (removed > 0) {
      this.localRevision++;
      this.onStoreChanged();
    }
    this.exitBulkMode();
  }

  private async publish(): Promise<void> {
    if (this.publishing || this.candidates().length === 0 || this.bulkMode) return;
    this.publishing = true;
    this.publishMessage = '';
    this.publishError = false;
    try {
      let result = await this.viewModel.publish();
      this.localRevision++;
      this.onStoreChanged();
      this.publishMessage = `已发布 ${result.publishedCount} 项作业`;
      this.onPublished();
    } catch (error) {
      this.publishError = true;
      let message = `${error}`;
      this.publishMessage = message.indexOf('离线') >= 0 ? '当前离线，待确认作业已保留；联网后可继续发布。' :
        '发布未完成，全部待确认作业均已保留，请检查网络或刷新后重试。';
    } finally {
      this.publishing = false;
    }
  }

  @Builder
  private CandidateEditorSheet() {
    if (this.editingCandidate() !== null) {
      ConfirmationCandidateEditor({
        item: this.editingCandidate()!,
        onClose: () => this.closeEditor(),
        onSave: (candidate: CandidateAssignment) => this.saveCandidate(candidate),
        onDelete: (candidateId: string) => this.removeCandidate(candidateId)
      });
    }
  }

  @Builder
  private CandidateListHeader() {
    Row({ space: 10 }) {
      Text(this.bulkMode ? `已选 ${this.selectedCandidateIds.length} 项` : '发布前最后核对')
        .layoutWeight(1)
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .maxLines(AppTheme.SECTION_TITLE_MAX_LINES)
        .fontColor(AppTheme.TEXT);

      if (this.bulkMode) {
        Text('全选')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 8 })
          .onClick(() => this.selectAllCandidates());
        Text('完成')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 4 })
          .onClick(() => this.exitBulkMode());
      } else {
        Text('＋ 新增')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('手工新增一项作业')
          .onClick(() => this.addCandidate());
        if (this.candidates().length > 0) {
          Text('管理')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 8, right: 4 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('批量管理待确认作业')
            .onClick(() => this.enterBulkMode());
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private CandidateList() {
    if (this.candidates().length === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(30).fontColor([AppTheme.SUCCESS]);
        Text('没有待确认作业').fontSize(AppTheme.CARD_TITLE_SIZE).lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .padding({ top: 30, bottom: 30 });
    } else {
      Column({ space: 7 }) {
        ForEach(this.candidates(), (item: CandidateAssignment) => {
          Row({ space: 8 }) {
            if (this.bulkMode) {
              Text(this.isCandidateSelected(item.id) ? '✓' : '')
                .width(28)
                .height(28)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isCandidateSelected(item.id) ? AppTheme.TEXT_ON_PRIMARY : AppTheme.SUBTEXT)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.isCandidateSelected(item.id) ? AppTheme.PRIMARY : AppTheme.SURFACE_EMPHASIS)
                .border({ width: 1, color: this.isCandidateSelected(item.id) ? AppTheme.PRIMARY : AppTheme.BORDER })
                .borderRadius(14)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText(this.isCandidateSelected(item.id) ? '取消选择这项作业' : '选择这项作业')
                .onClick(() => this.toggleCandidateSelection(item.id));
            }

            ConfirmationCandidateCard({
              item: item,
              selected: this.bulkMode ? this.isCandidateSelected(item.id) :
                (this.showEditorSheet && this.editingCandidateId === item.id),
              onSelect: () => {
                if (this.bulkMode) this.toggleCandidateSelection(item.id);
                else this.openEditor(item.id);
              },
              onMinutesChange: (candidate: CandidateAssignment, minutes: number) =>
                this.setExpectedMinutes(candidate, minutes)
            })
            .layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);
        }, (item: CandidateAssignment) => this.candidateRenderKey(item));
      }
      .width('100%');
    }
  }

  @Builder
  private PublishFeedback() {
    if (this.publishMessage.length > 0) {
      Text(this.publishMessage).width('100%').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT)
        .fontColor(this.publishError ? AppTheme.DANGER : AppTheme.SUCCESS)
        .padding(10)
        .backgroundColor(this.publishError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private BottomActionBar() {
    Column() {
      Column({ space: 8 }) {
        this.PublishFeedback();

        if (this.bulkMode) {
          if (this.batchDeleteConfirm) {
            Text(`确定删除选中的 ${this.selectedCandidateIds.length} 项待确认作业？`)
              .width('100%')
              .fontSize(AppTheme.BODY_SIZE)
              .lineHeight(AppTheme.BODY_LINE_HEIGHT)
              .fontColor(AppTheme.DANGER);
            Row({ space: 10 }) {
              Button('取消', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                .fontColor(AppTheme.TEXT)
                .onClick(() => this.batchDeleteConfirm = false);
              Button('确认删除', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.DANGER)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => this.removeSelectedCandidates());
            }
            .width('100%');
          } else {
            Button(this.selectedCandidateIds.length > 0 ?
              `删除选中的 ${this.selectedCandidateIds.length} 项` : '请选择要删除的作业',
              { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(this.selectedCandidateIds.length > 0)
              .backgroundColor(this.selectedCandidateIds.length > 0 ? AppTheme.DANGER : AppTheme.DISABLED)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => this.batchDeleteConfirm = true);
          }
        } else {
          Button(this.publishing ? '正在发布…' : `确认并发布 ${this.candidates().length} 项`,
            { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.publishing && this.candidates().length > 0)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.candidates().length > 0 ? AppTheme.PRIMARY : AppTheme.DISABLED)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.publish(); });
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 10, bottom: 14 });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
  }

  build() {
    Column() {
      Column({ space: 10 }) {
        DeepPageHeader({
          title: '确认发布',
          subtitle: `${this.candidates().length} 项待确认`,
          backAccessibilityText: '返回导入',
          onBack: () => this.onBack()
        });

        this.CandidateListHeader();
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING,
        bottom: 8
      });

      Scroll() {
        Column() {
          this.CandidateList();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH })
        .padding({
          left: AppTheme.PAGE_PADDING,
          right: AppTheme.PAGE_PADDING,
          top: 4,
          bottom: 16
        });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      this.BottomActionBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .bindSheet($$this.showEditorSheet, this.CandidateEditorSheet(), {
      height: '82%',
      showClose: false,
      preferType: SheetType.BOTTOM,
      onDisappear: () => this.completeEditorDismiss()
    });
  }
}
