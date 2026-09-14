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

  static resolve(widthVp: number): WindowSizeClass {
    if (widthVp <= 600) {
      return WindowSizeClass.COMPACT;
    }
    if (widthVp <= 840) {
      return WindowSizeClass.MEDIUM;
    }
    return WindowSizeClass.EXPANDED;
  }
}
