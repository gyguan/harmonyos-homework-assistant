import { AppTheme } from '../../common/theme/AppTheme';
import { CenteredTextBadge } from './CenteredTextBadge';

@Component
export struct IdentityContextBar {
  @Prop isParent: boolean = false;
  @Prop studentName: string = '';
  @Prop studentGrade: string = '';
  @Prop studentClassName: string = '';
  @Prop canSwitchStudent: boolean = false;
  onSwitchIdentity: () => void = () => {};
  onSwitchStudent: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      CenteredTextBadge({
        badgeText: this.isParent ? '家' :
          (this.studentName.length > 0 ? this.studentName.substring(0, 1) : '伴'),
        badgeWidth: 34,
        badgeHeight: 34,
        badgeFontSize: 13,
        badgeRadius: 11,
        badgeBold: true,
        badgeForeground: AppTheme.PRIMARY,
        badgeBackground: AppTheme.PRIMARY_SOFT
      });

      Column({ space: 1 }) {
        Text(this.isParent ? '家长' : this.studentName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.isParent ?
          '当前管理 · ' + this.studentName :
          this.studentGrade + ' · ' + this.studentClassName)
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);

      Blank();

      if (this.isParent && this.canSwitchStudent) {
        Row({ space: 4 }) {
          Text('管理 ' + this.studentName).fontSize(12).fontColor(AppTheme.PRIMARY);
          Text('⌄').fontSize(12).fontColor(AppTheme.PRIMARY);
        }
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(AppTheme.SURFACE)
        .border({ width: 1, color: AppTheme.BORDER })
        .borderRadius(AppTheme.CHIP_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('当前管理 ' + this.studentName + '，点击切换孩子')
        .onClick(() => this.onSwitchStudent());
      }

      Row({ space: 4 }) {
        Text('切换身份').fontSize(12).fontColor(AppTheme.PRIMARY);
        Text('⌄').fontSize(12).fontColor(AppTheme.PRIMARY);
      }
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 10, right: 10, top: 7, bottom: 7 })
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.isParent ?
        '当前身份家长，点击切换身份' : '当前身份 ' + this.studentName + '，点击切换身份')
      .onClick(() => this.onSwitchIdentity());
    }
    .width('100%')
    .height(AppTheme.CONTEXT_BAR_HEIGHT)
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
