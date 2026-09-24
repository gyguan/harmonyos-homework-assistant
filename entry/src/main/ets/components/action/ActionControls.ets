import { AppTheme } from '../../common/theme/AppTheme';

export enum ActionButtonKind {
  PRIMARY = 'PRIMARY',
  SECONDARY = 'SECONDARY',
  NEUTRAL = 'NEUTRAL',
  DANGER = 'DANGER',
  DANGER_SOFT = 'DANGER_SOFT'
}

export enum TextActionKind {
  PRIMARY = 'PRIMARY',
  NEUTRAL = 'NEUTRAL',
  DANGER = 'DANGER'
}

@Component
export struct ActionButton {
  @Prop label: string;
  @Prop kind: ActionButtonKind = ActionButtonKind.PRIMARY;
  @Prop isEnabled: boolean = true;
  @Prop compact: boolean = false;
  @Prop accessibilityLabel: string = '';
  onClick: () => void = () => {};

  private resolveButtonHeight(): number {
    return this.compact ? AppTheme.SECONDARY_BUTTON_HEIGHT : AppTheme.BUTTON_HEIGHT;
  }

  private resolveBackgroundColor(): string {
    if (!this.isEnabled && (this.kind === ActionButtonKind.PRIMARY || this.kind === ActionButtonKind.DANGER)) {
      return AppTheme.DISABLED;
    }
    if (this.kind === ActionButtonKind.SECONDARY) return AppTheme.PRIMARY_SOFT;
    if (this.kind === ActionButtonKind.NEUTRAL) return AppTheme.SURFACE_EMPHASIS;
    if (this.kind === ActionButtonKind.DANGER) return AppTheme.DANGER;
    if (this.kind === ActionButtonKind.DANGER_SOFT) return AppTheme.DANGER_SOFT;
    return AppTheme.PRIMARY;
  }

  private resolveForegroundColor(): string {
    if (this.kind === ActionButtonKind.SECONDARY) return AppTheme.PRIMARY;
    if (this.kind === ActionButtonKind.NEUTRAL) return AppTheme.TEXT;
    if (this.kind === ActionButtonKind.DANGER_SOFT) return AppTheme.DANGER;
    return AppTheme.TEXT_ON_PRIMARY;
  }

  build() {
    Button(this.label, { type: ButtonType.Normal })
      .height(this.resolveButtonHeight())
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .fontSize(this.compact ? 14 : 15)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.resolveBackgroundColor())
      .fontColor(this.resolveForegroundColor())
      .enabled(this.isEnabled)
      .accessibilityText(this.accessibilityLabel.length > 0 ? this.accessibilityLabel : this.label)
      .onClick(() => this.onClick());
  }
}

@Component
export struct TextAction {
  @Prop label: string;
  @Prop kind: TextActionKind = TextActionKind.PRIMARY;
  @Prop isEnabled: boolean = true;
  @Prop accessibilityLabel: string = '';
  onClick: () => void = () => {};

  private resolveForegroundColor(): string {
    if (!this.isEnabled) return AppTheme.DISABLED;
    if (this.kind === TextActionKind.NEUTRAL) return AppTheme.SUBTEXT;
    if (this.kind === TextActionKind.DANGER) return AppTheme.DANGER;
    return AppTheme.PRIMARY;
  }

  build() {
    Text(this.label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.resolveForegroundColor())
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 8, right: 8 })
      .textAlign(TextAlign.Center)
      .enabled(this.isEnabled)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.accessibilityLabel.length > 0 ? this.accessibilityLabel : this.label)
      .onClick(() => this.onClick());
  }
}
