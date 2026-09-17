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
    return LayoutPolicy.areaLengthToVp(value, fallbackVp);
  }

  // Window size class is retained only for the application navigation form.
  // Feature composition must use LayoutPolicy with actual available width.
  static resolve(widthVp: number): WindowSizeClass {
    if (!Number.isFinite(widthVp) || widthVp <= 0) return WindowSizeClass.COMPACT;
    if (widthVp <= 600) return WindowSizeClass.COMPACT;
    if (widthVp <= 840) return WindowSizeClass.MEDIUM;
    return WindowSizeClass.EXPANDED;
  }
}
