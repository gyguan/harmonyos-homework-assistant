import { BackendSession } from '../../../application/remote/BackendSession';
import { HomeworkRemoteApi } from '../../../application/remote/HomeworkRemoteApi';
import { HomeworkSyncService } from '../../../application/remote/HomeworkSyncService';
import { RemoteSubmission } from '../../../application/remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../../../application/remote/RemoteSubmissionCache';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { CloudSubmissionPhotoStrip } from '../../../components/submission/CloudSubmissionPhotoStrip';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Subject, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate, DueDateFilterKey } from '../../../domain/service/AssignmentDueDate';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct ParentProgressPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private reviewAssignmentId: string = '';
  @State private reviewNoteDraft: string = '';
  @State private selectedAssignmentId: string = '';
  @State private editing: boolean = false;
  @State private editSubject: Subject = Subject.CHINESE;
  @State private editTitle: string = '';
  @State private editInstruction: string = '';
  @State private editTextbookRef: string = '';
  @State private editDueText: string = '';
  @State private editExpectedMinutes: string = '20';
  @State private deleteConfirm: boolean = false;
  @State private operationNotice: string = '';
  @State private subjectFilter: string = 'ALL';
  @State private dateFilter: DueDateFilterKey = DueDateFilterKey.ALL;
  onStoreChanged: () => void = () => {};

  private assignments(): Assignment[] {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getAssignments();
  }

  private matchesSubject(item: Assignment, subject: string): boolean {
    return subject === 'ALL' || item.subject === subject;
  }

  private filteredAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, this.subjectFilter) && AssignmentDueDate.matches(item, this.dateFilter)) result.push(item);
    }
    return result;
  }

  private subjectCount(subject: string): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, subject) && AssignmentDueDate.matches(item, this.dateFilter)) count++;
    }
    return count;
  }

  private dateCount(dateFilter: DueDateFilterKey): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (this.matchesSubject(item, this.subjectFilter) && AssignmentDueDate.matches(item, dateFilter)) count++;
    }
    return count;
  }

  private selectedAssignment(): Assignment | null {
    let currentRevision = this.revision + this.localRevision;
    if (this.selectedAssignmentId.length === 0) return null;
    return HomeworkStore.instance.getAssignment(this.selectedAssignmentId);
  }

  private submissions(assignmentId: string): Submission[] {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId);
  }

  private latestLocalSubmission(assignmentId: string): Submission | null {
    let items = this.submissions(assignmentId);
    return items.length === 0 ? null : items[items.length - 1];
  }

  private remoteSubmissions(assignmentId: string): RemoteSubmission[] {
    let currentRevision = this.revision + this.localRevision;
    return RemoteSubmissionCache.instance.get(assignmentId);
  }

  private timingText(item: Assignment): string {
    if (item.status === AssignmentStatus.PAUSED) {
      let usedMinutes = item.elapsedSeconds > 0 ? Math.max(1, Math.round(item.elapsedSeconds / 60)) : 0;
      return `已暂停 · 已用 ${usedMinutes} 分钟 / 预计 ${item.expectedMinutes} 分钟`;
    }
    if (item.elapsedSeconds > 0 && item.status !== AssignmentStatus.IN_PROGRESS) {
      let actualMinutes = Math.max(1, Math.round(item.elapsedSeconds / 60));
      return `预计 ${item.expectedMinutes} 分钟 · 实际 ${actualMinutes} 分钟`;
    }
    if (item.status === AssignmentStatus.IN_PROGRESS && item.startedAtEpochMs > 0) {
      return `进行中 · 预计 ${item.expectedMinutes} 分钟`;
    }
    return `预计 ${item.expectedMinutes} 分钟`;
  }

  private openDetail(item: Assignment): void {
    this.selectedAssignmentId = item.id;
    this.editing = false;
    this.deleteConfirm = false;
    this.operationNotice = '';
  }

  private closeDetail(): void {
    this.selectedAssignmentId = '';
    this.editing = false;
    this.deleteConfirm = false;
    this.operationNotice = '';
  }

  private beginEdit(item: Assignment): void {
    this.editSubject = item.subject;
    this.editTitle = item.title;
    this.editInstruction = item.instruction;
    this.editTextbookRef = item.textbookRef;
    this.editDueText = item.dueText;
    this.editExpectedMinutes = `${item.expectedMinutes}`;
    this.editing = true;
    this.deleteConfirm = false;
    this.operationNotice = '';
  }

  private saveEdit(item: Assignment): void {
    let title = this.editTitle.trim();
    let minutes = Math.round(Number(this.editExpectedMinutes));
    if (title.length === 0) {
      this.operationNotice = '作业标题不能为空';
      return;
    }
    if (!Number.isFinite(minutes) || minutes < 1 || minutes > 240) {
      this.operationNotice = '预计时长请输入 1-240 分钟';
      return;
    }
    let updated: Assignment = {
      id: item.id,
      studentId: item.studentId,
      candidateId: item.candidateId,
      subject: this.editSubject,
      title: title,
      instruction: this.editInstruction.trim().length > 0 ? this.editInstruction.trim() : title,
      textbookRef: this.editTextbookRef.trim(),
      dueText: this.editDueText.trim(),
      status: item.status,
      expectedMinutes: minutes,
      startedAtEpochMs: item.startedAtEpochMs,
      finishedAtEpochMs: item.finishedAtEpochMs,
      elapsedSeconds: item.elapsedSeconds,
      reviewNote: item.reviewNote,
      remoteVersion: item.remoteVersion,
      syncDirty: true,
      lastSyncedAtEpochMs: item.lastSyncedAtEpochMs,
      resourceLabels: item.resourceLabels.slice()
    };
    let next: Assignment[] = [];
    for (let assignment of this.assignments()) next.push(assignment.id === item.id ? updated : assignment);
    HomeworkStore.instance.replaceAssignmentsForActiveStudent(next);
    this.editing = false;
    this.operationNotice = '已保存，正在同步家庭云端';
    this.localRevision++;
    this.onStoreChanged();
  }

  private removeLocalAssignment(assignmentId: string): void {
    let next: Assignment[] = [];
    for (let assignment of this.assignments()) if (assignment.id !== assignmentId) next.push(assignment);
    HomeworkStore.instance.replaceAssignmentsForActiveStudent(next);
    RemoteSubmissionCache.instance.remove(assignmentId);
    this.localRevision++;
    this.onStoreChanged();
  }

  private async confirmDelete(item: Assignment): Promise<void> {
    this.operationNotice = '';
    if (item.remoteVersion > 0) {
      if (!BackendSession.instance.isConnected()) {
        this.deleteConfirm = false;
        this.operationNotice = '该任务已同步到家庭云端，请连接家庭云端后再删除';
        return;
      }
      try {
        if (!await HomeworkRemoteApi.instance.delete(item.id)) {
          this.deleteConfirm = false;
          this.operationNotice = '云端删除失败，请稍后重试';
          return;
        }
      } catch {
        this.deleteConfirm = false;
        this.operationNotice = '云端删除失败，请检查网络连接';
        return;
      }
    }
    let id = item.id;
    this.closeDetail();
    this.removeLocalAssignment(id);
  }

  private openReview(item: Assignment): void {
    this.reviewAssignmentId = item.id;
    this.reviewNoteDraft = item.reviewNote;
  }

  private closeReview(): void {
    this.reviewAssignmentId = '';
    this.reviewNoteDraft = '';
  }

  private submitReview(item: Assignment, completed: boolean): void {
    let note = this.reviewNoteDraft.trim();
    if (!completed && note.length === 0) return;
    if (HomeworkStore.instance.reviewAssignment(item.id, completed, note)) {
      this.closeReview();
      this.localRevision++;
      this.onStoreChanged();
      HomeworkSyncService.instance.requestSync();
    }
  }

  @Builder
  private LocalSubmission(submission: Submission) {
    Column({ space: 10 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`最新提交 · ${submission.fileLabel}`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
        Blank();
        Text(submission.submittedAtText).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Scroll() {
        Row({ space: 9 }) {
          ForEach(submission.photoUris, (uri: string) => {
            Image(uri).width(86).height(86).objectFit(ImageFit.Cover).borderRadius(12).backgroundColor(AppTheme.SURFACE_EMPHASIS);
          }, (uri: string) => uri);
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
    }.width('100%').padding(12).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private CloudSubmission(submission: RemoteSubmission) {
    Column({ space: 8 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`云端已提交 · ${submission.photos.length} 张照片`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
      }.width('100%');
      Text(submission.submittedAt.replace('T', ' ').substring(0, 16))
        .width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      CloudSubmissionPhotoStrip({ photos: submission.photos });
      Text('照片通过家庭账号鉴权加载，并缓存在当前设备。')
        .width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
    }.width('100%').padding(12).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private ReviewPane(item: Assignment) {
    if (item.status === AssignmentStatus.SUBMITTED) {
      if (this.reviewAssignmentId === item.id) {
        Column({ space: 10 }) {
          Text('家长验收').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          TextArea({ placeholder: '可写一句鼓励；如果需要订正，请告诉孩子具体改哪里。', text: this.reviewNoteDraft })
            .width('100%').height(86).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.reviewNoteDraft = value.substring(0, 1000));
          Row({ space: 8 }) {
            Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.SUBTEXT)
              .onClick(() => this.closeReview());
            Button('需要订正', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).enabled(this.reviewNoteDraft.trim().length > 0)
              .backgroundColor(AppTheme.WARNING_SOFT).fontColor(AppTheme.WARNING)
              .onClick(() => this.submitReview(item, false));
            Button('确认完成', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => this.submitReview(item, true));
          }.width('100%');
        }.width('100%').padding(13).backgroundColor(AppTheme.PRIMARY_FAINT).borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Button('验收作业', { type: ButtonType.Normal }).width('100%').height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
          .onClick(() => this.openReview(item));
      }
    } else if (item.reviewNote.length > 0 &&
      (item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.COMPLETED)) {
      Column({ space: 4 }) {
        Text(item.status === AssignmentStatus.NEEDS_REWORK ? '订正说明' : '家长留言')
          .width('100%').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(item.status === AssignmentStatus.NEEDS_REWORK ? AppTheme.WARNING : AppTheme.SUCCESS);
        Text(item.reviewNote).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.TEXT);
      }.width('100%').padding(12)
        .backgroundColor(item.status === AssignmentStatus.NEEDS_REWORK ? AppTheme.WARNING_SOFT : AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private DetailValue(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(86)
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
      Text(value.length > 0 ? value : '未填写')
        .layoutWeight(1)
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 });
  }

  @Builder
  private SubjectChip(subject: Subject) {
    Text(subject)
      .fontSize(AppTheme.CAPTION_SIZE)
      .fontWeight(this.editSubject === subject ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.editSubject === subject ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.editSubject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.editSubject === subject ? `${subject}，已选择` : subject)
      .onClick(() => this.editSubject = subject);
  }

  @Builder
  private EditPane(item: Assignment) {
    Column({ space: 12 }) {
      Text('编辑任务').width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text('学科').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        this.SubjectChip(Subject.CHINESE);
        this.SubjectChip(Subject.MATH);
        this.SubjectChip(Subject.ENGLISH);
      }.width('100%');
      Text('作业标题').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.editTitle }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.editTitle = value.substring(0, 200));
      Text('作业说明').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      TextArea({ text: this.editInstruction, placeholder: '填写给孩子的具体作业要求' }).width('100%').height(96)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.editInstruction = value.substring(0, 1000));
      Text('教材 / 页码').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.editTextbookRef }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.editTextbookRef = value.substring(0, 200));
      Text('截止时间').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.editDueText }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.editDueText = value.substring(0, 100));
      Text('预计完成时间（分钟）').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.editExpectedMinutes }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.editExpectedMinutes = value.substring(0, 3));
      Row({ space: 8 }) {
        Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.SUBTEXT)
          .onClick(() => this.editing = false);
        Button('保存修改', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.saveEdit(item));
      }.width('100%');
    }.width('100%').padding(16).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private DeletePane(item: Assignment) {
    if (this.deleteConfirm) {
      Column({ space: 9 }) {
        Text('确认删除这项任务？').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.DANGER);
        Text('删除后，孩子端将不再看到该任务；已经产生的提交记录、辅导记录和云端作业照片也会一起删除。')
          .width('100%').fontSize(AppTheme.CAPTION_SIZE).lineHeight(18).fontColor(AppTheme.SUBTEXT);
        Row({ space: 8 }) {
          Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.SUBTEXT)
            .onClick(() => this.deleteConfirm = false);
          Button('确认删除', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.DANGER).fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.confirmDelete(item); });
        }.width('100%');
      }.width('100%').padding(13).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private AssignmentDetail(item: Assignment) {
    Column({ space: 16 }) {
      Row() {
        if (this.sizeClass === WindowSizeClass.COMPACT) {
          Text('‹ 作业进度')
            .fontSize(14)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 4, right: 8 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('返回作业进度列表')
            .onClick(() => this.closeDetail());
        }
        Blank();
        Text(AssignmentStateMachine.label(item.status)).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
      }.width('100%');

      Column({ space: 7 }) {
        Text(item.subject).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
        Text(item.title).width('100%').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text(`${HomeworkStore.instance.getStudent().name} · ${HomeworkStore.instance.getStudent().className}`)
          .width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }.width('100%').alignItems(HorizontalAlign.Start);

      if (this.editing) {
        this.EditPane(item);
      } else {
        Column({ space: 0 }) {
          this.DetailValue('作业说明', item.instruction);
          Divider().color(AppTheme.DIVIDER);
          this.DetailValue('教材 / 页码', item.textbookRef);
          Divider().color(AppTheme.DIVIDER);
          this.DetailValue('截止时间', item.dueText);
          Divider().color(AppTheme.DIVIDER);
          this.DetailValue('完成时间', this.timingText(item));
          Divider().color(AppTheme.DIVIDER);
          this.DetailValue('同步状态', item.syncDirty ? '本机有修改，待同步' : (item.remoteVersion > 0 ? '已同步家庭云端' : '仅本机'));
        }.width('100%').padding({ left: 14, right: 14 }).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);

        Row({ space: 8 }) {
          Button('编辑任务', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
            .onClick(() => this.beginEdit(item));
          Button('删除任务', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.DANGER_SOFT).fontColor(AppTheme.DANGER)
            .onClick(() => { this.deleteConfirm = true; this.operationNotice = ''; });
        }.width('100%');
      }

      if (this.operationNotice.length > 0) {
        Text(this.operationNotice).width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT)
          .padding(10).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
      }

      this.DeletePane(item);

      if (this.latestLocalSubmission(item.id) !== null) {
        this.LocalSubmission(this.latestLocalSubmission(item.id)!);
      } else if (this.remoteSubmissions(item.id).length > 0) {
        this.CloudSubmission(this.remoteSubmissions(item.id)[0]);
      }
      this.ReviewPane(item);
    }.width('100%');
  }

  @Builder
  private SubjectTab(key: string, label: string) {
    Column({ space: 5 }) {
      Text(`${label} ${this.subjectCount(key)}`)
        .fontSize(13)
        .fontWeight(this.subjectFilter === key ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.subjectFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      Divider()
        .width('100%')
        .strokeWidth(this.subjectFilter === key ? 2 : 0)
        .color(this.subjectFilter === key ? AppTheme.PRIMARY : Color.Transparent);
    }
    .height(AppTheme.MIN_TOUCH_TARGET)
    .padding({ left: 6, right: 6 })
    .justifyContent(FlexAlign.End)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.subjectFilter === key ? `${label}，已选择，${this.subjectCount(key)}项` : `${label}，${this.subjectCount(key)}项`)
    .onClick(() => this.subjectFilter = key);
  }

  @Builder
  private DateTab(key: DueDateFilterKey, label: string) {
    Text(`${label} ${this.dateCount(key)}`)
      .fontSize(12)
      .fontWeight(this.dateFilter === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.dateFilter === key ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.dateFilter === key ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.dateFilter === key ? `${label}，已选择，${this.dateCount(key)}项` : `${label}，${this.dateCount(key)}项`)
      .onClick(() => this.dateFilter = key);
  }

  @Builder
  private FilterPanel() {
    Column({ space: 8 }) {
      Scroll() {
        Row({ space: 18 }) {
          this.SubjectTab('ALL', '全部');
          this.SubjectTab(Subject.CHINESE, '语文');
          this.SubjectTab(Subject.MATH, '数学');
          this.SubjectTab(Subject.ENGLISH, '英语');
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
      Scroll() {
        Row({ space: 4 }) {
          this.DateTab(DueDateFilterKey.ALL, '全部日期');
          this.DateTab(DueDateFilterKey.TODAY, '今天');
          this.DateTab(DueDateFilterKey.TOMORROW, '明天');
          this.DateTab(DueDateFilterKey.THIS_WEEK, '本周');
          this.DateTab(DueDateFilterKey.OVERDUE, '逾期');
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
    }.width('100%');
  }

  @Builder
  private ProgressList() {
    Column({ space: 18 }) {
      Column({ space: 4 }) {
        Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text(`${HomeworkStore.instance.getStudent().name} · 查看完成、提交和验收状态`).fontSize(13).fontColor(AppTheme.SUBTEXT);
      }.width('100%').alignItems(HorizontalAlign.Start);

      this.FilterPanel();

      if (this.filteredAssignments().length === 0) {
        Column({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
          Text(this.assignments().length === 0 ? '暂时没有作业' : '当前筛选下没有作业')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        }.width('100%').padding({ top: 28, bottom: 28 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.filteredAssignments(), (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.selectedAssignmentId === item.id,
              onOpen: () => this.openDetail(item)
            });
          }, (item: Assignment) => item.id);
        }.width('100%');
      }
    }.width('100%');
  }

  @Builder
  private EmptyDetail() {
    Column({ space: 9 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(34)
        .fontColor([AppTheme.TERTIARY_TEXT]);
      Text('选择一项作业')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text('在左侧选择后，可查看提交照片、验收、编辑或删除。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(32);
  }

  @Builder
  private PhoneLayout() {
    Scroll() {
      Column() {
        if (this.selectedAssignment() !== null) {
          this.AssignmentDetail(this.selectedAssignment()!);
        } else {
          this.ProgressList();
        }
      }
      .width('100%')
      .padding(AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }

  @Builder
  private PadLayout() {
    Row() {
      Scroll() {
        this.ProgressList();
      }
      .width(this.sizeClass === WindowSizeClass.EXPANDED ? '38%' : '43%')
      .height('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING)
      .scrollBar(BarState.Off);

      Divider().vertical(true).height('100%').color(AppTheme.DIVIDER);

      Scroll() {
        Column() {
          if (this.selectedAssignment() !== null) {
            this.AssignmentDetail(this.selectedAssignment()!);
          } else {
            this.EmptyDetail();
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .height('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING)
      .backgroundColor(AppTheme.SURFACE)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%');
  }

  build() {
    if (this.sizeClass === WindowSizeClass.COMPACT) {
      this.PhoneLayout();
    } else {
      this.PadLayout();
    }
  }
}