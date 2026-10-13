import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentStatus, Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentAttentionKind } from '../../../domain/service/AssignmentAttentionPolicy';
import { StudentHomeViewModel } from './StudentHomeViewModel';

interface StudentHomeSubjectGroup {
  subject: Subject;
  items: Assignment[];
}

@Component
struct StudentPendingTaskCard {
  @Prop assignment: Assignment;
  @Prop busy: boolean = false;
  onAction: (assignmentId: string) => void = (_assignmentId: string) => {};

  private subjectColor(): string {
    if (this.assignment.subject === Subject.CHINESE) return AppTheme.DANGER;
    if (this.assignment.subject === Subject.MATH) return AppTheme.PRIMARY;
    if (this.assignment.subject === Subject.ENGLISH) return '#7A3EF0';
    if (this.assignment.subject === Subject.SPORTS || this.assignment.subject === Subject.PRACTICE) {
      return AppTheme.SUCCESS;
    }
    return AppTheme.WARNING;
  }

  private subjectBackground(): string {
    if (this.assignment.subject === Subject.CHINESE) return AppTheme.DANGER_SOFT;
    if (this.assignment.subject === Subject.MATH) return AppTheme.PRIMARY_SOFT;
    if (this.assignment.subject === Subject.ENGLISH) return '#F1EBFF';
    if (this.assignment.subject === Subject.SPORTS || this.assignment.subject === Subject.PRACTICE) {
      return AppTheme.SUCCESS_SOFT;
    }
    return AppTheme.WARNING_SOFT;
  }

  private statusLabel(): string {
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS) return '正在做';
    if (this.assignment.status === AssignmentStatus.PAUSED) return '已暂停';
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK) return '要订正';
    if (this.assignment.status === AssignmentStatus.OVERDUE) return '已逾期';
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return '待提交';
    return '未开始';
  }

  private actionLabel(): string {
    if (this.busy) return '请稍候…';
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS ||
      this.assignment.status === AssignmentStatus.PAUSED) return '继续';
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK) return '去订正';
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return '去提交';
    return '开始';
  }

  private statusColor(): string {
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK ||
      this.assignment.status === AssignmentStatus.OVERDUE) return AppTheme.DANGER;
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return AppTheme.SUCCESS;
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS ||
      this.assignment.status === AssignmentStatus.PAUSED) return AppTheme.PRIMARY;
    return AppTheme.SUBTEXT;
  }

  build() {
    Row({ space: 10 }) {
      CenteredTextBadge({
        badgeText: this.assignment.subject.substring(0, 1),
        badgeWidth: 40,
        badgeHeight: 40,
        badgeFontSize: 16,
        badgeRadius: 12,
        badgeBold: true,
        badgeForeground: this.subjectColor(),
        badgeBackground: this.subjectBackground()
      });

      Column({ space: 5 }) {
        Text(this.assignment.title)
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Row({ space: 5 }) {
          Text(this.statusLabel())
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor());
          Text('·')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${this.assignment.expectedMinutes} 分钟`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Button(this.actionLabel(), { type: ButtonType.Normal })
        .width(82)
        .height(AppTheme.MIN_TOUCH_TARGET)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.busy)
        .backgroundColor(this.busy ? AppTheme.DISABLED : AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .accessibilityText(`${this.actionLabel()}${this.assignment.title}`)
        .onClick(() => this.onAction(this.assignment.id));
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(13)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityText(
      `${this.assignment.subject}，${this.assignment.title}，${this.statusLabel()}，预计${this.assignment.expectedMinutes}分钟`);
  }
}

@Component
export struct StudentHomePage {
  @Prop @Watch('onStudentIdChanged') studentId: string = '';
  @Prop offlineMode: boolean = false;
  @Prop @Watch('onRevisionChanged') revision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private actionAssignmentId: string = '';
  @State private actionMessage: string = '';
  @State private pendingTaskItems: Assignment[] = [];
  @State private subjectGroups: StudentHomeSubjectGroup[] = [];
  @State private taskRenderEpoch: number = 0;
  @State private attentionMessage: string = '';
  @State private attentionCategory: AssignmentAttentionKind = AssignmentAttentionKind.NONE;
  private identityGeneration: number = 0;
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};
  onOpenAttention: (kind: AssignmentAttentionKind) => void = (_kind: AssignmentAttentionKind) => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: StudentHomeViewModel =
    new StudentHomeViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    this.refreshTodaySnapshot();
  }

  private onRevisionChanged(): void {
    this.refreshTodaySnapshot();
  }

  private onStudentIdChanged(): void {
    this.identityGeneration++;
    this.actionAssignmentId = '';
    this.actionMessage = '';
    this.pendingTaskItems = [];
    this.subjectGroups = [];
    this.attentionMessage = '';
    this.attentionCategory = AssignmentAttentionKind.NONE;
    this.refreshTodaySnapshot();
  }

  private subjectOrder(): Subject[] {
    return [
      Subject.CHINESE,
      Subject.MATH,
      Subject.ENGLISH,
      Subject.READING,
      Subject.READ_ALOUD,
      Subject.SPORTS,
      Subject.PRACTICE,
      Subject.INTEREST,
      Subject.OTHER
    ];
  }

  private buildSubjectGroups(items: Assignment[]): StudentHomeSubjectGroup[] {
    let result: StudentHomeSubjectGroup[] = [];
    let order = this.subjectOrder();
    for (let subject of order) {
      let subjectItems: Assignment[] = [];
      for (let item of items) {
        if (item.subject === subject) subjectItems.push(item);
      }
      if (subjectItems.length > 0) result.push({ subject: subject, items: subjectItems });
    }
    return result;
  }

  private refreshTodaySnapshot(): void {
    if (this.studentId.length === 0) {
      this.pendingTaskItems = [];
      this.subjectGroups = [];
      this.attentionMessage = '';
      this.attentionCategory = AssignmentAttentionKind.NONE;
      return;
    }
    let items = this.viewModel.todayPendingAssignments(this.studentId);
    let attention = this.viewModel.attention(this.studentId);
    this.pendingTaskItems = items;
    this.subjectGroups = this.buildSubjectGroups(items);
    this.taskRenderEpoch++;
    this.attentionMessage = attention.text;
    this.attentionCategory = attention.kind;
    let firstTaskId = items.length > 0 ? items[0].id : '';
    console.info('[STUDENT-HOME] refresh studentId=' + this.studentId +
      ' todayPendingTasks=' + String(items.length) + ' subjectGroups=' + String(this.subjectGroups.length) +
      ' firstTaskId=' + firstTaskId + ' revision=' + String(this.revision) +
      ' renderEpoch=' + String(this.taskRenderEpoch));
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${this.taskRenderEpoch}|${item.studentId}|${item.id}|${item.remoteVersion}|${item.subjectCode}|${item.subject}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  private subjectRenderKey(group: StudentHomeSubjectGroup): string {
    return `${this.taskRenderEpoch}|${group.subject}|${group.items.length}`;
  }

  private async openAssignment(assignmentId: string): Promise<void> {
    if (this.actionAssignmentId.length > 0) return;
    let item = this.viewModel.assignment(assignmentId);
    if (item === null || item.studentId !== this.studentId) return;
    let actionStudentId = this.studentId;
    let actionGeneration = this.identityGeneration;
    this.actionMessage = '';
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.READY_TO_SUBMIT) {
      if (actionGeneration === this.identityGeneration && actionStudentId === this.studentId) {
        this.onOpenStudy(item.id);
      }
      return;
    }

    this.actionAssignmentId = assignmentId;
    try {
      await this.viewModel.performAction(assignmentId, AssignmentAction.START);
      if (actionGeneration !== this.identityGeneration || actionStudentId !== this.studentId) return;
      this.onStoreChanged();
      this.onOpenStudy(assignmentId);
    } catch {
      if (actionGeneration === this.identityGeneration && actionStudentId === this.studentId) {
        this.actionMessage = '暂时无法开始，请稍后再试';
      }
    } finally {
      if (actionGeneration === this.identityGeneration && actionStudentId === this.studentId) {
        this.actionAssignmentId = '';
      }
    }
  }

  @Builder
  private OfflineBanner() {
    if (this.offlineMode) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.wifi_slash')).fontSize(17).fontColor([AppTheme.WARNING]);
        Text('当前离线，可以查看已缓存的今日作业。')
          .layoutWeight(1)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.WARNING_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private AttentionBanner() {
    if (this.attentionMessage.length > 0) {
      Row({ space: 8 }) {
        Text('提醒')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.WARNING);
        Text(this.attentionMessage)
          .layoutWeight(1)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.TEXT);
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.WARNING_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(`提醒，${this.attentionMessage}，点击查看`)
      .onClick(() => this.onOpenAttention(this.attentionCategory));
    }
  }

  @Builder
  private EmptyState() {
    Row({ space: 11 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(27)
        .fontColor([AppTheme.SUCCESS]);
      Column({ space: 3 }) {
        Text('今天的作业都完成啦')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('今天没有待完成的作业。')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SUCCESS_SOFT)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private SubjectTaskSection(group: StudentHomeSubjectGroup) {
    Column({ space: 9 }) {
      Row() {
        Text(group.subject)
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${group.items.length} 项`)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Column({ space: 10 }) {
        ForEach(group.items, (item: Assignment) => {
          StudentPendingTaskCard({
            assignment: item,
            busy: this.actionAssignmentId === item.id,
            onAction: (assignmentId: string) => { void this.openAssignment(assignmentId); }
          });
        }, (item: Assignment) => this.assignmentRenderKey(item));
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private PendingTasks() {
    Column({ space: AppTheme.SECTION_GAP_STANDARD }) {
      Row() {
        Text('今日待完成')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.pendingTaskItems.length > 0) {
          Text(`${this.pendingTaskItems.length} 项`)
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.subjectGroups.length === 0) {
        this.EmptyState();
      } else {
        ForEach(this.subjectGroups, (group: StudentHomeSubjectGroup) => {
          this.SubjectTaskSection(group);
        }, (group: StudentHomeSubjectGroup) => this.subjectRenderKey(group));
      }

      if (this.actionMessage.length > 0) {
        Text(this.actionMessage)
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%');
  }

  @Builder
  private HomeContent() {
    Column({ space: AppTheme.SECTION_GAP_COMPACT }) {
      this.OfflineBanner();
      this.AttentionBanner();
      this.PendingTasks();
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
    .padding({
      left: LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
      right: LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
      top: 14,
      bottom: 24
    });
  }

  build() {
    Scroll() {
      Column() {
        this.HomeContent();
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((_oldValue, newValue) => {
        this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
      });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .backgroundColor(AppTheme.BACKGROUND)
    .scrollBar(BarState.Off);
  }
}
