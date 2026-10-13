import { HomeworkCoverageParent, HomeworkCoverageRemoteApi } from '../../../application/remote/HomeworkCoverageRemoteApi';
import { BackendSession } from '../../../application/remote/BackendSession';
import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import {
  HomeworkCoveragePicker,
  HomeworkCoverageSubject
} from '../../../components/assignment/HomeworkCoveragePicker';
import { AssignmentTaskDate } from '../../../domain/service/AssignmentTaskDate';
import { AssignmentAttentionKind } from '../../../domain/service/AssignmentAttentionPolicy';
import { ParentDashboardViewModel } from './ParentDashboardViewModel';

@Component
export struct ParentDashboardPage {
  @Watch('onCoverageContextChanged') @Prop revision: number = 0;
  @Watch('onCoverageContextChanged') @Prop studentId: string = '';
  @State private availableWidthVp: number = 390;
  @State private coverageParents: HomeworkCoverageParent[] = [];
  @State private coverageStudentName: string = '';
  @State private coverageBusy: boolean = false;
  @State private coverageMessage: string = '';
  @State private showCoverageEditor: boolean = false;
  @State private coverageDraft: string[] = [];
  private readonly viewModel: ParentDashboardViewModel = new ParentDashboardViewModel();
  private readonly coverageApi: HomeworkCoverageRemoteApi = HomeworkCoverageRemoteApi.instance;
  onOpenAssignment: () => void = () => {};
  onOpenVoice: () => void = () => {};
  onOpenScheduled: () => void = () => {};
  onOpenPracticeGeneration: () => void = () => {};
  onOpenAttention: (kind: AssignmentAttentionKind) => void = (_kind: AssignmentAttentionKind) => {};

  aboutToAppear(): void {
    void this.refreshCoverage();
  }

  private onCoverageContextChanged(): void {
    void this.refreshCoverage();
  }

  private async refreshCoverage(): Promise<void> {
    if (this.studentId.length === 0 || !BackendSession.instance.isConnected()) {
      this.coverageParents = [];
      this.coverageStudentName = '';
      this.coverageMessage = '';
      return;
    }
    this.coverageBusy = true;
    try {
      let response = await this.coverageApi.get(this.studentId, AssignmentTaskDate.today());
      if (response.studentId !== this.studentId) return;
      this.coverageParents = response.parents.slice();
      this.coverageStudentName = response.studentName;
      this.coverageMessage = '';
    } catch {
      this.coverageMessage = '今日作业协同状态暂时无法加载';
    } finally {
      this.coverageBusy = false;
    }
  }

  private mineSubjects(): string[] {
    for (let parent of this.coverageParents) if (parent.mine) return parent.subjects.slice();
    return [];
  }

  private openCoverageEditor(): void {
    if (!BackendSession.instance.isConnected() || this.studentId.length === 0) return;
    this.coverageDraft = this.mineSubjects();
    this.coverageMessage = '';
    this.showCoverageEditor = true;
  }

  private async saveCoverage(): Promise<void> {
    if (this.coverageBusy) return;
    this.coverageBusy = true;
    this.coverageMessage = '';
    try {
      let response = await this.coverageApi.updateMine(
        this.studentId, AssignmentTaskDate.today(), this.coverageDraft);
      this.coverageParents = response.parents.slice();
      this.coverageStudentName = response.studentName;
      this.showCoverageEditor = false;
    } catch {
      this.coverageMessage = '保存失败，请检查家庭云端连接后重试';
    } finally {
      this.coverageBusy = false;
    }
  }

  private parentCoverageText(parent: HomeworkCoverageParent): string {
    if (HomeworkCoverageSubject.contains(parent.subjects, HomeworkCoverageSubject.ALL)) {
      return '已确认今天全部作业已布置';
    }
    let labels = HomeworkCoverageSubject.labels(parent.subjects);
    return labels.length > 0 ? `已布置：${labels}` : '暂未标记';
  }

  private coverageComplete(): boolean {
    for (let parent of this.coverageParents) {
      if (HomeworkCoverageSubject.contains(parent.subjects, HomeworkCoverageSubject.ALL)) return true;
    }
    return false;
  }

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
  }

  private attentionText(): string {
    let currentRevision = this.revision;
    if (currentRevision < 0) return '';
    return this.viewModel.attentionText();
  }

  @Builder
  private HomeworkCoverageCard() {
    if (BackendSession.instance.isConnected()) {
      Column({ space: 9 }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.coverageComplete() ?
            $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.person_2_fill'))
            .fontSize(20)
            .fontColor([this.coverageComplete() ? AppTheme.SUCCESS : AppTheme.PRIMARY]);
          Column({ space: 2 }) {
            Text(this.coverageComplete() ? '今日作业已安排完成' : '今日作业协同')
              .width('100%')
              .fontSize(AppTheme.CARD_TITLE_SIZE)
              .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text((this.coverageStudentName.length > 0 ? this.coverageStudentName : '当前孩子') +
              ' · ' + AssignmentTaskDate.displayText(AssignmentTaskDate.today()))
              .width('100%')
              .fontSize(AppTheme.CAPTION_SIZE)
              .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Text('修改')
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
        }
        .width('100%');

        if (this.coverageParents.length === 0) {
          Text(this.coverageBusy ? '正在同步家庭成员的布置状态…' : '还没有家长标记今天已布置的作业')
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        } else {
          Column({ space: 6 }) {
            ForEach(this.coverageParents, (parent: HomeworkCoverageParent) => {
              Row({ space: 8 }) {
                Text(parent.displayName + (parent.mine ? '（我）' : ''))
                  .fontSize(AppTheme.META_SIZE)
                  .lineHeight(AppTheme.META_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(parent.mine ? AppTheme.PRIMARY : AppTheme.TEXT);
                Text(this.parentCoverageText(parent))
                  .layoutWeight(1)
                  .fontSize(AppTheme.META_SIZE)
                  .lineHeight(AppTheme.META_LINE_HEIGHT)
                  .fontColor(this.parentCoverageText(parent).indexOf('全部') >= 0 ?
                    AppTheme.SUCCESS : AppTheme.SUBTEXT)
                  .maxLines(2);
              }
              .width('100%');
            }, (parent: HomeworkCoverageParent) =>
              `${parent.displayName}|${parent.mine}|${parent.subjects.join(',')}|${parent.updatedAt}`);
          }
          .width('100%');
        }

        if (this.coverageMessage.length > 0) {
          Text(this.coverageMessage)
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.WARNING);
        }
      }
      .width('100%')
      .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
      .backgroundColor(this.coverageComplete() ? AppTheme.SUCCESS_SOFT : AppTheme.CARD_SURFACE)
      .border({ width: 1, color: this.coverageComplete() ? AppTheme.SUCCESS : AppTheme.BORDER })
      .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('今日作业协同，点击查看或修改我的布置状态')
      .onClick(() => this.openCoverageEditor());
    }
  }

  @Builder
  private HomeworkCoverageEditor() {
    Column() {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('今日作业协同')
            .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('只修改你自己的标记，不会改变其他家长的状态')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('关闭')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .onClick(() => this.showCoverageEditor = false);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 14 }) {
          if (this.coverageParents.length > 0) {
            Column({ space: 6 }) {
              Text('家庭当前状态')
                .width('100%')
                .fontSize(AppTheme.LABEL_TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              ForEach(this.coverageParents, (parent: HomeworkCoverageParent) => {
                Row({ space: 8 }) {
                  Text(parent.displayName + (parent.mine ? '（我）' : ''))
                    .fontSize(AppTheme.META_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(parent.mine ? AppTheme.PRIMARY : AppTheme.TEXT);
                  Text(this.parentCoverageText(parent))
                    .layoutWeight(1)
                    .fontSize(AppTheme.META_SIZE)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .width('100%');
              }, (parent: HomeworkCoverageParent) =>
                `editor|${parent.displayName}|${parent.mine}|${parent.subjects.join(',')}|${parent.updatedAt}`);
            }
            .width('100%')
            .padding(AppTheme.CARD_PADDING_COMPACT)
            .backgroundColor(AppTheme.CARD_SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }

          HomeworkCoveragePicker({
            selected: this.coverageDraft,
            disabled: this.coverageBusy,
            title: '我今天已经布置',
            description: '“全部”表示你确认当前孩子今天需要布置的作业已经全部处理完成',
            onChange: (subjects: string[]) => this.coverageDraft = subjects.slice()
          });

          if (this.coverageMessage.length > 0) {
            Text(this.coverageMessage)
              .width('100%')
              .fontSize(AppTheme.META_SIZE)
              .fontColor(AppTheme.DANGER);
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 16 });
      }
      .width('100%')
      .layoutWeight(1);

      Button(this.coverageBusy ? '正在保存…' : '保存我的状态', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .margin({ left: 16, right: 16, bottom: 18 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.coverageBusy)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.saveCoverage(); });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.SURFACE);
  }

  @Builder
  private AttentionBanner() {
    if (this.attentionText().length > 0) {
      Row({ space: 8 }) {
        Text('需要关注')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.WARNING);
        Text(this.attentionText())
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
      .accessibilityText(`需要关注，${this.attentionText()}，点击查看`)
      .onClick(() => this.onOpenAttention(this.viewModel.attentionKind()));
    }
  }

  @Builder
  private CreateAssignmentAction() {
    Column({ space: 14 }) {
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.plus_square'))
            .fontSize(24)
            .fontColor([AppTheme.PRIMARY]);
        }
        .width(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .height(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .alignContent(Alignment.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%');

      Column({ space: 5 }) {
        Text('布置作业')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('输入文字、拍照或相册识别')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('布置作业，输入文字、拍照或相册识别')
    .onClick(() => this.onOpenAssignment());
  }

  @Builder
  private CreateVoiceAction() {
    Column({ space: 14 }) {
      Row() {
        Stack() {
          Text('♪')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
        }
        .width(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .height(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .alignContent(Alignment.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%');

      Column({ space: 5 }) {
        Text('语音作业')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('使用语音和图片快速布置')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('语音作业，使用语音和图片快速布置')
    .onClick(() => this.onOpenVoice());
  }

  @Builder
  private ScheduledAssignmentAction() {
    Column({ space: 14 }) {
      Row() {
        Stack() {
          Text('时')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
        }
        .width(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .height(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .alignContent(Alignment.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%');

      Column({ space: 5 }) {
        Text('定时作业')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('按计划自动创建普通或语音作业')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('定时作业，按计划自动创建普通或语音作业')
    .onClick(() => this.onOpenScheduled());
  }

  @Builder
  private AiPracticeAction() {
    Column({ space: 14 }) {
      Row() {
        Stack() {
          Text('AI')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
        }
        .width(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .height(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .alignContent(Alignment.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%');

      Column({ space: 5 }) {
        Text('AI生成练习')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('按训练目标生成题库，预览后发布给孩子')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('AI生成练习，按训练目标生成题库，预览后发布给孩子')
    .onClick(() => this.onOpenPracticeGeneration());
  }

  @Builder
  private PhoneHome() {
    Scroll() {
      Column() {
        Column({ space: 10 }) {
          this.HomeworkCoverageCard();
          this.AttentionBanner();
          this.CreateAssignmentAction();
          this.CreateVoiceAction();
          this.ScheduledAssignmentAction();
          this.AiPracticeAction();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
        .padding({
          left: LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
          right: LayoutPolicy.pagePaddingForWidth(this.availableWidthVp),
          top: 18,
          bottom: 24
        });
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
      Column({ space: 18 }) {
        this.HomeworkCoverageCard();
        this.AttentionBanner();
        Row({ space: AppTheme.SPLIT_PANE_GAP }) {
          Column() {
            this.CreateAssignmentAction();
          }
          .layoutWeight(1);

          Column() {
            this.CreateVoiceAction();
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);

        Row({ space: AppTheme.SPLIT_PANE_GAP }) {
          Column() {
            this.ScheduledAssignmentAction();
          }
          .layoutWeight(1);

          Column() {
            this.AiPracticeAction();
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.CONTENT_WIDE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING_WIDE,
        right: AppTheme.PAGE_PADDING_WIDE,
        top: 24,
        bottom: 24
      });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  build() {
    Column() {
      if (this.canUseWideComposition()) this.WideHome();
      else this.PhoneHome();
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    })
    .bindSheet($this.showCoverageEditor, this.HomeworkCoverageEditor(), {
      height: '72%',
      showClose: false,
      preferType: SheetType.BOTTOM
    });
  }
}
