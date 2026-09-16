import { display } from '@kit.ArkUI';

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

  private static fallbackDisplayWidthVp(): number {
    try {
      let displayInfo = display.getDefaultDisplaySync();
      if (displayInfo.densityPixels > 0) {
        return displayInfo.width / displayInfo.densityPixels;
      }
    } catch (_error) {
      // Keep a safe Phone-first fallback if display metrics are temporarily unavailable.
    }
    return 390;
  }

  private static normalizeWidthVp(widthValue: number): number {
    if (!Number.isFinite(widthValue) || widthValue <= 0) {
      return ResponsiveContext.fallbackDisplayWidthVp();
    }

    try {
      let displayInfo = display.getDefaultDisplaySync();
      if (displayInfo.densityPixels <= 0) return widthValue;

      // Area.width should be vp. Some Preview/runtime combinations can surface the
      // physical full-screen width instead. Detect only that full-screen case so
      // normal split/free-window vp widths continue to use the component area.
      let physicalWidthPx = displayInfo.width;
      if (Math.abs(widthValue - physicalWidthPx) <= 2) {
        return physicalWidthPx / displayInfo.densityPixels;
      }
    } catch (_error) {
      return widthValue;
    }

    return widthValue;
  }

  static resolve(widthValue: number): WindowSizeClass {
    let widthVp = ResponsiveContext.normalizeWidthVp(widthValue);
    if (widthVp <= 600) {
      return WindowSizeClass.COMPACT;
    }
    if (widthVp <= 840) {
      // 600–840vp still uses the single-column content layout. This covers large
      // phones, foldable narrow windows and tablet portrait without squeezing a
      // Pad master-detail layout into a narrow viewport. Two-column content is
      // reserved for EXPANDED windows only.
      return WindowSizeClass.COMPACT;
    }
    return WindowSizeClass.EXPANDED;
  }
}
