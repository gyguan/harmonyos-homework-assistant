import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { HomeworkCaptureHomeViewModel } from './HomeworkCaptureHomeViewModel';

@Component
export struct HomeworkCaptureHomePage {
  @Prop revision: number = 0;
  @State private showGuide: boolean = false;
  onBack: () => void = () => {};
  onStartCapture: () => void = () => {};
  onOpenSourceProfile: (startCaptureAfterSave: boolean) => void = (_startCaptureAfterSave: boolean) => {};
  onOpenHistory: () => void = () => {};
  onOpenDiagnostics: () => void = () => {};
  private readonly viewModel: HomeworkCaptureHomeViewModel = new HomeworkCaptureHomeViewModel();

  private hasSourceProfile(): boolean {
    let currentRevision = this.revision;
    if (currentRevision < 0) return false;
    return this.viewModel.hasSourceProfile();
  }

  private startCapture(): void {
    if (!this.hasSourceProfile()) {
      this.onOpenSourceProfile(true);
      return;
    }
    this.onStartCapture();
  }

  @Builder
  private SourceRow(label: string, value: string) {
    Row() {
      Text(label)
        .width(82)
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
      Text(value)
        .layoutWeight(1)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .constraintSize({ minHeight: 32 });
  }

  @Builder
  private SourceCard() {
    Column({ space: 10 }) {
      Text('当前来源')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      if (this.hasSourceProfile()) {
        this.SourceRow('班级', this.viewModel.profileName());
        Divider().color(AppTheme.DIVIDER);
        this.SourceRow('学生', this.viewModel.studentName());
        Divider().color(AppTheme.DIVIDER);
        this.SourceRow('微信群', this.viewModel.groupTitle());
        Divider().color(AppTheme.DIVIDER);
        this.SourceRow('老师', this.viewModel.teacherSummary());
        Divider().color(AppTheme.DIVIDER);
        this.SourceRow('抓取时间范围', this.viewModel.timeWindow());
      } else {
        Column({ space: 8 }) {
          Text('源')
            .width(44)
            .height(44)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(14);
          Text('尚未配置来源')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('请先设置班级、学生和微信群信息，再开始抓取作业。')
            .fontSize(13)
            .lineHeight(19)
            .fontColor(AppTheme.SUBTEXT)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding({ top: 10, bottom: 12 })
        .alignItems(HorizontalAlign.Center);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private SecondaryAction(icon: string, label: string, onAction: () => void) {
    Column({ space: 7 }) {
      Text(icon)
        .width(32)
        .height(32)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(10);
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .textAlign(TextAlign.Center)
        .maxLines(1);
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 72 })
    .justifyContent(FlexAlign.Center)
    .padding({ left: 6, right: 6, top: 8, bottom: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .onClick(() => onAction());
  }

  @Builder
  private UsageGuide() {
    Column({ space: 9 }) {
      Row() {
        Text('使用说明')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('收起')
          .fontSize(12)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('收起使用说明')
      .onClick(() => this.showGuide = false);

      Text('1. 点击开始后授权屏幕采集。')
        .width('100%')
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
      Text('2. 切换到目标微信群，从最新消息开始手工向上滑动。')
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(AppTheme.SUBTEXT);
      Text('3. 看到悬浮提示达到今日时间范围后，结束抓取并返回确认。')
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(AppTheme.SUBTEXT);

      Text('仅处理当前屏幕内容，不读取微信数据库，不自动点击或滚动微信，不使用 Accessibility 驱动微信。')
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(AppTheme.TERTIARY_TEXT);

      Divider().color(AppTheme.DIVIDER);

      Row() {
        Text('抓取异常？')
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
        Blank();
        Text('屏幕采集技术诊断 ›')
          .fontSize(12)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('打开屏幕采集技术诊断')
      .onClick(() => this.onOpenDiagnostics());
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '抓取老师作业',
        subtitle: '从老师群聊中提取今日作业',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          this.SourceCard();

          Button(this.hasSourceProfile() ? '开始抓取' : '先配置并开始抓取', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .fontSize(15)
            .onClick(() => this.startCapture());

          Row({ space: 8 }) {
            this.SecondaryAction('设', '班级采集设置', () => this.onOpenSourceProfile(false));
            this.SecondaryAction('记', '抓取记录', () => this.onOpenHistory());
            this.SecondaryAction('?', '使用说明', () => this.showGuide = !this.showGuide);
          }
          .width('100%');

          if (this.showGuide) {
            this.UsageGuide();
          }

          Row({ space: 6 }) {
            Text('i')
              .width(18)
              .height(18)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.PRIMARY)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(9);
            Text('抓取结束后，仍需家长确认后才能导入作业。')
              .layoutWeight(1)
              .fontSize(12)
              .lineHeight(18)
              .fontColor(AppTheme.TERTIARY_TEXT);
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 4, bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.CAPTURE_HOME_READABLE_MAX_WIDTH })
        .padding({ top: 4 });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.PAGE_PADDING,
      right: AppTheme.PAGE_PADDING,
      top: AppTheme.DEEP_PAGE_TOP_PADDING
    })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
