import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { AssignmentMetricSummary } from '../../../components/assignment/AssignmentMetricSummary';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, StudentProfile } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';
import { ParentHomeViewModel } from './ParentHomeViewModel';

@Component
export struct ParentDashboardPage {
  @Prop revision: number = 0;
  @Prop activeStudentId: string = '';
  @State private availableWidthVp: number = 390;
  onOpenImport: () => void = () => {};
  onOpenCapture: () => void = () => {};
  onOpenExtra: () => void = () => {};
  onOpenVoice: () => void = () => {};
  onOpenProgress: () => void = () => {};
  onOpenReview: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: ParentHomeViewModel =
    new ParentHomeViewModel(DefaultAssignmentRepository.instance);

  private touchRevision(): number {
    return this.revision;
  }

  private student(): StudentProfile {
    let currentRevision = this.touchRevision();
    let student = this.viewModel.student();
    if (currentRevision < 0) return student;
    if (this.activeStudentId.length > 0 && student.id !== this.activeStudentId) return student;
    return student;
  }

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
  }

  private attentionAssignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.attentionAssignments();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.assignments();
  }

  private todayAssignments(): Assignment[] {
    let result: Assignment[] = [];
    let todayStart = AssignmentDueDate.businessDayStart(Date.now());
    for (let item of this.assignments()) {
      if (AssignmentDueDate.dayStart(item) === todayStart) result.push(item);
    }
    return result;
  }

  private todayPendingCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) {
      if (item.status !== AssignmentStatus.SUBMITTED && item.status !== AssignmentStatus.COMPLETED) count++;
    }
    return count;
  }

  private todaySubmittedCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) if (item.status === AssignmentStatus.SUBMITTED) count++;
    return count;
  }

  private todayCompletedCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) if (item.status === AssignmentStatus.COMPLETED) count++;
    return count;
  }

  private submittedCount(): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.SUBMITTED) count++;
    }
    return count;
  }

  private openAttention(item: Assignment): void {
    if (item.status === AssignmentStatus.SUBMITTED || item.status === AssignmentStatus.COMPLETED ||
      item.status === AssignmentStatus.NEEDS_REWORK) {
      this.onOpenReview(item.id);
    } else {
      this.onOpenProgress();
    }
  }

  @Builder
  private TodayOverview() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今日概览')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text(`${this.todayAssignments().length} 项`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      AssignmentMetricSummary({
        allCount: this.todayAssignments().length,
        pendingCount: this.todayPendingCount(),
        submittedCount: this.todaySubmittedCount(),
        completedCount: this.todayCompletedCount()
      });

      Progress({
        value: this.todayCompletedCount(),
        total: this.todayAssignments().length > 0 ? this.todayAssignments().length : 1,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT);
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  @Builder
  private AttentionSection() {
    if (this.attentionAssignments().length > 0) {
      Column({ space: 9 }) {
        Row() {
          Text('需要我处理')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Blank();
          Text(`${this.attentionAssignments().length} 项`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        Column({ space: 7 }) {
          ForEach(this.attentionAssignments(), (item: Assignment) => {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(item.subject)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.PRIMARY);
                  Text(item.status === AssignmentStatus.SUBMITTED ? '待验收' : AssignmentStateMachine.label(item.status))
                    .fontSize(13)
                    .fontColor(item.status === AssignmentStatus.SUBMITTED ? AppTheme.WARNING : AppTheme.DANGER);
                }
                Text(item.title)
                  .width('100%')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(15)
                .fontColor([AppTheme.TERTIARY_TEXT]);
            }
            .width('100%')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 10, top: 10, bottom: 10 })
            .backgroundColor(item.status === AssignmentStatus.SUBMITTED ? AppTheme.WARNING_SOFT : AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(`${item.subject}，${item.title}，${AssignmentStateMachine.label(item.status)}`)
            .onClick(() => this.openAttention(item));
          }, (item: Assignment) => this.assignmentRenderKey(item));
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private RecentActivity() {
    Column({ space: 9 }) {
      Row() {
        Text('最近动态')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('查看作业进度')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 4 })
          .onClick(() => this.onOpenProgress());
      }
      .width('100%');

      if (this.assignments().length === 0) {
        Text('还没有发布作业')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .padding({ top: 18, bottom: 18 })
          .textAlign(TextAlign.Center);
      } else {
        Column({ space: 6 }) {
          ForEach(this.assignments().slice(0, 3), (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              showChevron: true,
              onOpen: () => this.openAttention(item)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }

      if (this.viewModel.recentSubmitted() !== null) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(18)
            .fontColor([AppTheme.SUCCESS]);
          Text('最近提交')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          Text(`${this.viewModel.recentSubmitted()!.subject} · ${this.viewModel.recentSubmitted()!.title}`)
            .layoutWeight(1)
            .fontSize(13)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .padding({ left: 11, right: 11, top: 9, bottom: 9 })
        .backgroundColor(AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('查看最近提交')
        .onClick(() => this.onOpenReview(this.viewModel.recentSubmitted()!.id));
      }
    }
    .width('100%');
  }

  @Builder
  private QuickActions() {
    Column({ space: 9 }) {
      Text('快捷操作')
        .width('100%')
        .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Row({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.plus_square')).fontSize(19).fontColor([AppTheme.PRIMARY]);
          Column({ space: 2 }) {
            Text('手工导入作业').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('老师截图、文字或分享').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 64 })
        .padding(11)
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`给 ${this.student().name} 手工导入老师作业`)
        .onClick(() => this.onOpenImport());

        Row({ space: 8 }) {
          Text('抓')
            .width(22)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
          Column({ space: 2 }) {
            Text('抓取老师作业').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('进班级群手工上滑').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 64 })
        .padding(11)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`给 ${this.student().name} 抓取老师作业`)
        .onClick(() => this.onOpenCapture());
      }
      .width('100%');

      Row({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.plus_square')).fontSize(19).fontColor([AppTheme.SUCCESS]);
          Column({ space: 2 }) {
            Text('课外任务').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('阅读、体育、实践').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 64 })
        .padding(11)
        .backgroundColor(AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`给 ${this.student().name} 布置课外任务`)
        .onClick(() => this.onOpenExtra());

        Row({ space: 8 }) {
          Text('♪')
            .width(22)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
          Column({ space: 2 }) {
            Text('语音作业').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('语音和情景图片').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 64 })
        .padding(11)
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`给 ${this.student().name} 布置语音作业`)
        .onClick(() => this.onOpenVoice());
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private ChildPerformance() {
    Column({ space: 12 }) {
      Text('孩子表现')
        .width('100%')
        .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Row() {
        Text('今日完成').fontSize(13).fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`${this.viewModel.summary().completed} / ${this.viewModel.summary().total}`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
      }
      .width('100%');
      Divider().color(AppTheme.DIVIDER);
      Row() {
        Text('待家长验收').fontSize(13).fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`${this.submittedCount()} 项`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.WARNING);
      }
      .width('100%');
      Divider().color(AppTheme.DIVIDER);
      Row() {
        Text('需关注').fontSize(13).fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`${this.attentionAssignments().length} 项`)
          .fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.attentionAssignments().length > 0 ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private SingleColumnHome() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.PHONE_SECTION_GAP }) {
          this.TodayOverview();
          this.AttentionSection();
          this.RecentActivity();
          this.QuickActions();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_HOME_READABLE_MAX_WIDTH })
        .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING, top: 14, bottom: 20 });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  @Builder
  private WideHome() {
    Scroll() {
      Row({ space: AppTheme.SPLIT_PANE_GAP }) {
        Column({ space: 18 }) {
          this.TodayOverview();
          this.AttentionSection();
          this.RecentActivity();
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Column({ space: 14 }) {
          this.ChildPerformance();
          this.QuickActions();
        }
        .width(AppTheme.PARENT_HOME_SECONDARY_MIN_WIDTH)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_HOME_PAD_CONTENT_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 20, bottom: 20 })
      .alignItems(VerticalAlign.Top);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  build() {
    Column() {
      if (this.canUseWideComposition()) {
        this.WideHome();
      } else {
        this.SingleColumnHome();
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
