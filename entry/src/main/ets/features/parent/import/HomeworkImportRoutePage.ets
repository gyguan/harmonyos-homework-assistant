import { HomeworkSourceProfileService } from '../../../application/capture/HomeworkSourceProfileService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { HomeworkImportPage } from './HomeworkImportPage';

@Component
export struct HomeworkImportRoutePage {
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onOpenCapture: () => void = () => {};
  onOpenSourceProfile: (startCaptureAfterSave: boolean) => void = (_startCaptureAfterSave: boolean) => {};
  onOpenCaptureSpike: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private profileSubtitle(): string {
    let currentRevision = this.revision;
    if (currentRevision < 0) return '';
    let studentId = DefaultFamilyContextRepository.instance.getActiveStudentId();
    let profile = HomeworkSourceProfileService.instance.getActiveProfile(studentId);
    if (profile === null) return '首次使用先配置班级群、老师和抓取时间';
    return `${profile.groupTitle} · 今天 ${HomeworkSourceProfileService.instance.formatStartTime(profile)} 至现在`;
  }

  private openCapture(): void {
    let studentId = DefaultFamilyContextRepository.instance.getActiveStudentId();
    if (HomeworkSourceProfileService.instance.getActiveProfile(studentId) === null) {
      this.onOpenSourceProfile(true);
      return;
    }
    this.onOpenCapture();
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '导入老师作业',
        subtitle: '老师原文 → 小伴整理 → 家长确认发布',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });
      Row({ space: 10 }) {
        Text('箱')
          .width(28)
          .height(28)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.PRIMARY)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(9);
        Column({ space: 2 }) {
          Text('作业智能收件箱')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('查看每次导入的来源、原始消息和候选作业')
            .fontSize(11)
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
      .accessibilityText('打开作业智能收件箱')
      .onClick(() => this.onOpenInbox());

      Row({ space: 10 }) {
        Text('采')
          .width(28)
          .height(28)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.PRIMARY)
          .borderRadius(9);
        Column({ space: 2 }) {
          Text('抓取今日作业')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(this.profileSubtitle())
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('抓取今日作业')
      .onClick(() => this.openCapture());

      Row() {
        Text('班级采集设置')
          .fontSize(12)
          .fontColor(AppTheme.PRIMARY);
        Blank();
        Text('修改 ›')
          .fontSize(12)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 10, right: 10 })
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('修改班级采集设置')
      .onClick(() => this.onOpenSourceProfile(false));

      Row({ space: 10 }) {
        Text('验')
          .width(28)
          .height(28)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .borderRadius(9);
        Column({ space: 2 }) {
          Text('屏幕采集技术诊断')
            .fontSize(13)
            .fontColor(AppTheme.TEXT);
          Text('#241 · AVScreenCapture / OCR / FloatView 真机 Gate')
            .fontSize(10)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('›').fontSize(18).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('打开屏幕采集技术诊断')
      .onClick(() => this.onOpenCaptureSpike());

      Column() {
        HomeworkImportPage({
          revision: this.revision,
          embeddedInDeepPage: true,
          onOpenConfirmation: () => this.onOpenConfirmation(),
          onStoreChanged: () => this.onStoreChanged()
        });
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: AppTheme.DEEP_PAGE_TOP_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
