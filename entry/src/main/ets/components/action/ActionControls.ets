import { AppTheme } from '../../common/theme/AppTheme';

export enum ActionButtonKind {
  PRIMARY = 'PRIMARY',
  SECONDARY = 'SECONDARY',
  NEUTRAL = 'NEUTRAL',
  OUTLINE = 'OUTLINE',
  GHOST = 'GHOST',
  WARNING = 'WARNING',
  DANGER = 'DANGER',
  DANGER_SOFT = 'DANGER_SOFT'
}

export enum ActionButtonSize {
  LARGE = 'LARGE',
  MEDIUM = 'MEDIUM',
  SMALL = 'SMALL'
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
  @Prop size: ActionButtonSize = ActionButtonSize.LARGE;
  @Prop isEnabled: boolean = true;
  // Temporary compatibility for already-migrated pages. New code should use size explicitly.
  @Prop compact: boolean = false;
  @Prop accessibilityLabel: string = '';
  onAction: () => void = () => {};

  private effectiveSize(): ActionButtonSize {
    if (this.compact) return ActionButtonSize.SMALL;
    return this.size;
  }

  private resolveButtonHeight(): number {
    let value = this.effectiveSize();
    if (value === ActionButtonSize.SMALL) return AppTheme.MIN_TOUCH_TARGET;
    if (value === ActionButtonSize.MEDIUM) return AppTheme.SECONDARY_BUTTON_HEIGHT;
    return AppTheme.BUTTON_HEIGHT;
  }

  private resolveFontSize(): number {
    let value = this.effectiveSize();
    if (value === ActionButtonSize.SMALL) return 13;
    if (value === ActionButtonSize.MEDIUM) return 14;
    return 15;
  }

  private resolveHorizontalPadding(): number {
    let value = this.effectiveSize();
    if (value === ActionButtonSize.SMALL) return 12;
    if (value === ActionButtonSize.MEDIUM) return 14;
    return 16;
  }

  private resolveBackgroundColor(): string {
    if (!this.isEnabled) {
      if (this.kind === ActionButtonKind.PRIMARY || this.kind === ActionButtonKind.DANGER) return AppTheme.DISABLED;
      if (this.kind === ActionButtonKind.GHOST) return '#00000000';
      return AppTheme.SURFACE_SUBTLE;
    }
    if (this.kind === ActionButtonKind.SECONDARY) return AppTheme.PRIMARY_SOFT;
    if (this.kind === ActionButtonKind.NEUTRAL) return AppTheme.SURFACE_EMPHASIS;
    if (this.kind === ActionButtonKind.OUTLINE) return AppTheme.SURFACE;
    if (this.kind === ActionButtonKind.GHOST) return '#00000000';
    if (this.kind === ActionButtonKind.WARNING) return AppTheme.WARNING_SOFT;
    if (this.kind === ActionButtonKind.DANGER) return AppTheme.DANGER;
    if (this.kind === ActionButtonKind.DANGER_SOFT) return AppTheme.DANGER_SOFT;
    return AppTheme.PRIMARY;
  }

  private resolveForegroundColor(): string {
    if (!this.isEnabled) return AppTheme.DISABLED;
    if (this.kind === ActionButtonKind.SECONDARY || this.kind === ActionButtonKind.OUTLINE ||
      this.kind === ActionButtonKind.GHOST) return AppTheme.PRIMARY;
    if (this.kind === ActionButtonKind.NEUTRAL) return AppTheme.TEXT;
    if (this.kind === ActionButtonKind.WARNING) return AppTheme.WARNING;
    if (this.kind === ActionButtonKind.DANGER_SOFT) return AppTheme.DANGER;
    return AppTheme.TEXT_ON_PRIMARY;
  }

  private resolveBorderWidth(): number {
    return this.kind === ActionButtonKind.OUTLINE ? 1 : 0;
  }

  private resolveBorderColor(): string {
    if (this.kind !== ActionButtonKind.OUTLINE) return '#00000000';
    return this.isEnabled ? AppTheme.BORDER : AppTheme.DIVIDER;
  }

  build() {
    Button(this.label, { type: ButtonType.Normal })
      .height(this.resolveButtonHeight())
      .padding({ left: this.resolveHorizontalPadding(), right: this.resolveHorizontalPadding() })
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .fontSize(this.resolveFontSize())
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.resolveBackgroundColor())
      .fontColor(this.resolveForegroundColor())
      .border({ width: this.resolveBorderWidth(), color: this.resolveBorderColor() })
      .enabled(this.isEnabled)
      .accessibilityText(this.accessibilityLabel.length > 0 ? this.accessibilityLabel : this.label)
      .onClick(() => this.onAction());
  }
}

@Component
export struct TextAction {
  @Prop label: string;
  @Prop kind: TextActionKind = TextActionKind.PRIMARY;
  @Prop isEnabled: boolean = true;
  @Prop accessibilityLabel: string = '';
  onAction: () => void = () => {};

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
      .padding({ left: 6, right: 6 })
      .textAlign(TextAlign.Center)
      .enabled(this.isEnabled)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.accessibilityLabel.length > 0 ? this.accessibilityLabel : this.label)
      .onClick(() => this.onAction());
  }
}
