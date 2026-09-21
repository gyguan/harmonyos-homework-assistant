import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { HomeworkCaptureHomeViewModel } from './HomeworkCaptureHomeViewModel';

@Component
export struct HomeworkCaptureHomePage {
  @Prop revision: number = 0;
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

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '抓取老师作业',
        subtitle: '进入班级群手工上滑，小伴自动识别并整理',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Row({ space: 10 }) {
              Text('抓')
                .width(34)
                .height(34)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .textAlign(TextAlign.Center)
                .backgroundColor(AppTheme.PRIMARY)
                .borderRadius(10);
              Column({ space: 3 }) {
                Text('从老师群聊中抓取今日作业')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text('授权后切到目标微信群，从最新消息开始手工向上滑动。')
                  .fontSize(13)
                  .lineHeight(19)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%');

            Text('小伴只处理你主动展示的当前屏幕，不读取微信数据库，不自动点击或滚动微信，不使用 Accessibility 驱动微信。')
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(AppTheme.TERTIARY_TEXT);
          }
          .width('100%')
          .padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.PRIMARY_FAINT)
          .borderRadius(AppTheme.CARD_RADIUS);

          Column({ space: 10 }) {
            Row() {
              Text('当前抓取来源')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Blank();
              Text(this.hasSourceProfile() ? '已配置' : '待配置')
                .fontSize(12)
                .fontColor(this.hasSourceProfile() ? AppTheme.SUCCESS : AppTheme.WARNING)
                .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .backgroundColor(this.hasSourceProfile() ? AppTheme.SUCCESS_SOFT : AppTheme.WARNING_SOFT)
                .borderRadius(AppTheme.CHIP_RADIUS);
            }
            .width('100%');

            Column({ space: 6 }) {
              Text(this.viewModel.profileName())
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text(`微信群：${this.viewModel.groupTitle()}`)
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              Text(`老师：${this.viewModel.teacherSummary()}`)
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              Text(`抓取范围：${this.viewModel.timeWindow()}`)
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            Row() {
              Text(this.hasSourceProfile() ? '修改班级采集设置' : '配置班级采集设置')
                .fontSize(13)
                .fontColor(AppTheme.PRIMARY);
              Blank();
              Text('›').fontSize(18).fontColor(AppTheme.PRIMARY);
            }
            .width('100%')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(this.hasSourceProfile() ? '修改班级采集设置' : '配置班级采集设置')
            .onClick(() => this.onOpenSourceProfile(false));
          }
          .width('100%')
          .padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CARD_RADIUS);

          Button(this.hasSourceProfile() ? '开始抓取' : '先配置并开始抓取', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => this.startCapture());

          Row({ space: 10 }) {
            Text('记')
              .width(30)
              .height(30)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.PRIMARY)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(9);
            Column({ space: 2 }) {
              Text('抓取记录')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text('查看历史批次、来源消息和整理结果')
                .fontSize(12)
                .fontColor(AppTheme.SUBTEXT);
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
            Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
          }
          .width('100%')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .accessibilityGroup(true)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('查看抓取记录')
          .onClick(() => this.onOpenHistory());

          Row({ space: 10 }) {
            Text('验')
              .width(30)
              .height(30)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.SUBTEXT)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .borderRadius(9);
            Column({ space: 2 }) {
              Text('屏幕采集技术诊断')
                .fontSize(13)
                .fontColor(AppTheme.TEXT);
              Text('仅用于 AVScreenCapture / OCR / FloatView 真机排查')
                .fontSize(12)
                .fontColor(AppTheme.TERTIARY_TEXT);
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
            Text('›').fontSize(18).fontColor(AppTheme.TERTIARY_TEXT);
          }
          .width('100%')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .accessibilityGroup(true)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('打开屏幕采集技术诊断')
          .onClick(() => this.onOpenDiagnostics());

          Text('抓取结束后会自动重建聊天消息并整理候选作业，最终仍由家长确认后发布。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.TERTIARY_TEXT)
            .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
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
