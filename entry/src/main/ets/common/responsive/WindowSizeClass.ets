import { AppTheme } from '../theme/AppTheme';
import { LayoutPolicy } from './LayoutPolicy';

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
    return LayoutPolicy.requiredWidth(LayoutPolicy.assignmentMasterDetailRequirement());
  }

  static canUseTwoPane(availableWidthVp: number): boolean {
    return LayoutPolicy.canSplit(availableWidthVp, LayoutPolicy.assignmentMasterDetailRequirement());
  }

  // Window size class is retained only for navigation form. Content layout uses
  // LayoutPolicy with the actual remaining content width.
  static resolve(widthVp: number): WindowSizeClass {
    if (!Number.isFinite(widthVp) || widthVp <= 0) return WindowSizeClass.COMPACT;
    if (widthVp <= 600) return WindowSizeClass.COMPACT;
    if (widthVp <= 840) return WindowSizeClass.MEDIUM;
    return WindowSizeClass.EXPANDED;
  }

  // Migration helper for legacy surfaces that still accept a size class. New V2 Feature
  // composition must consume LayoutPolicy directly instead of branching on this value.
  static resolveContent(availableWidthVp: number): WindowSizeClass {
    return ResponsiveContext.canUseTwoPane(availableWidthVp) ? WindowSizeClass.EXPANDED : WindowSizeClass.COMPACT;
  }
}
