import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { ParentDashboardViewModel } from './ParentDashboardViewModel';

@Component
export struct ParentDashboardPage {
  @Prop revision: number = 0;
  @State private availableWidthVp: number = 390;
  private readonly viewModel: ParentDashboardViewModel = new ParentDashboardViewModel();
  onOpenAssignment: () => void = () => {};
  onOpenVoice: () => void = () => {};
  onOpenScheduled: () => void = () => {};
  onOpenPracticeGeneration: () => void = () => {};

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
  }

  private attentionText(): string {
    let currentRevision = this.revision;
    if (currentRevision < 0) return '';
    return this.viewModel.attentionText();
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
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.WARNING_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityText(`需要关注，${this.attentionText()}`);
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
    });
  }
}
