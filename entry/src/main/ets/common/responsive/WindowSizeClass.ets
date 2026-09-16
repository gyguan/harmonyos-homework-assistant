import { AppTheme } from '../theme/AppTheme';

export enum WindowSizeClass {
  COMPACT = 'COMPACT',
  MEDIUM = 'MEDIUM',
  EXPANDED = 'EXPANDED'
}

export class ResponsiveContext {
  widthVp: number;
  heightVp: number;
  sizeClass: WindowSizeClass;
  isLandscape: boolean;

  constructor(widthVp: number, heightVp: number) {
    this.widthVp = widthVp;
    this.heightVp = heightVp;
    this.sizeClass = ResponsiveContext.resolve(widthVp);
    this.isLandscape = widthVp > heightVp;
  }

  static areaLengthToVp(value: Length, fallbackVp: number): number {
    if (typeof value === 'number') {
      return Number.isFinite(value) && value > 0 ? value : fallbackVp;
    }

    let parsed = Number.parseFloat(String(value));
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackVp;
  }

  static twoPaneRequiredWidthVp(): number {
    return AppTheme.SPLIT_PRIMARY_MIN_WIDTH +
      AppTheme.SPLIT_SECONDARY_MIN_WIDTH +
      AppTheme.SPLIT_PANE_GAP +
      AppTheme.PAGE_PADDING_WIDE * 2;
  }

  static canUseTwoPane(availableWidthVp: number): boolean {
    return Number.isFinite(availableWidthVp) && availableWidthVp >= ResponsiveContext.twoPaneRequiredWidthVp();
  }

  // Window size class is retained only for navigation form. Content layout uses
  // resolveContent() and is based on the actual remaining content width.
  static resolve(widthVp: number): WindowSizeClass {
    if (!Number.isFinite(widthVp) || widthVp <= 0) return WindowSizeClass.COMPACT;
    if (widthVp <= 600) return WindowSizeClass.COMPACT;
    if (widthVp <= 840) return WindowSizeClass.MEDIUM;
    return WindowSizeClass.EXPANDED;
  }

  static resolveContent(availableWidthVp: number): WindowSizeClass {
    return ResponsiveContext.canUseTwoPane(availableWidthVp) ? WindowSizeClass.EXPANDED : WindowSizeClass.COMPACT;
  }
}
