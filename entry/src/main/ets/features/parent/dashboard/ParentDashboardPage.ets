import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';

@Component
export struct ParentDashboardPage {
  @State private availableWidthVp: number = 390;
  onOpenAssignment: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onOpenVoice: () => void = () => {};

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
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
        .borderRadius(13);
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
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('输入文字、拍照或相册识别')
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
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
        .borderRadius(13);
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
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('使用语音和图片快速布置')
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('语音作业，使用语音和图片快速布置')
    .onClick(() => this.onOpenVoice());
  }

  @Builder
  private AssignmentInboxAction() {
    Column({ space: 14 }) {
      Row() {
        Stack() {
          Text('箱')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center);
        }
        .width(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .height(AppTheme.PARENT_HOME_ACTION_ICON_SIZE)
        .alignContent(Alignment.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(13);
        Blank();
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%');

      Column({ space: 5 }) {
        Text('作业收件箱')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('查看已导入的作业内容和整理记录')
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.PARENT_HOME_ACTION_CARD_MIN_HEIGHT })
    .padding(AppTheme.PARENT_HOME_ACTION_CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('作业收件箱，查看已导入的作业内容和整理记录')
    .onClick(() => this.onOpenInbox());
  }

  @Builder
  private PhoneHome() {
    Scroll() {
      Column() {
        Column({ space: 10 }) {
          this.CreateAssignmentAction();
          this.CreateVoiceAction();
          this.AssignmentInboxAction();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_HOME_READABLE_MAX_WIDTH })
        .padding({
          left: AppTheme.PHONE_PAGE_PADDING,
          right: AppTheme.PHONE_PAGE_PADDING,
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
        Row({ space: AppTheme.SPLIT_PANE_GAP }) {
          Column() {
            this.CreateAssignmentAction();
          }
          .layoutWeight(1);

          Column() {
            this.CreateVoiceAction();
          }
          .layoutWeight(1);

          Column() {
            this.AssignmentInboxAction();
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_HOME_PAD_CONTENT_MAX_WIDTH })
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
