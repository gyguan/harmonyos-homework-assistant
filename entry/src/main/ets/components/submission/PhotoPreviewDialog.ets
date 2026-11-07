import { AppTheme } from '../../common/theme/AppTheme';

const PHOTO_MIN_SCALE: number = 1;
const PHOTO_MAX_SCALE: number = 4;
const PHOTO_DOUBLE_TAP_SCALE: number = 2.5;
const PHOTO_SCALE_EPSILON: number = 0.001;

@CustomDialog
export struct PhotoPreviewDialog {
  controller: CustomDialogController;
  @Link @Watch('onUriChanged') uri: string;

  @State private zoomScale: number = PHOTO_MIN_SCALE;
  @State private panX: number = 0;
  @State private panY: number = 0;
  // 手势开始时的手势基准值：捏合按「起始倍率 × 本次手势倍率」算，拖动按「起始位移 + 本次位移」算
  private baseScale: number = PHOTO_MIN_SCALE;
  private basePanX: number = 0;
  private basePanY: number = 0;
  // 视口尺寸（vp）与图片原始尺寸（换算成 vp），用来算放大后能拖到多远
  private viewWidth: number = 0;
  private viewHeight: number = 0;
  private sourceWidth: number = 0;
  private sourceHeight: number = 0;

  aboutToAppear(): void {
    this.resetTransform();
  }

  onUriChanged(): void {
    this.resetTransform();
  }

  private resetTransform(): void {
    this.zoomScale = PHOTO_MIN_SCALE;
    this.panX = 0;
    this.panY = 0;
    this.baseScale = PHOTO_MIN_SCALE;
    this.basePanX = 0;
    this.basePanY = 0;
    this.sourceWidth = 0;
    this.sourceHeight = 0;
  }

  private isZoomed(): boolean {
    return this.zoomScale > PHOTO_MIN_SCALE + PHOTO_SCALE_EPSILON;
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max);
  }

  /**
   * 图片按 Contain 铺进视口后的实际显示尺寸（再乘缩放倍率）。
   * 只有知道这个尺寸，才能把拖动范围限制在图片边界内，而不是让人把图片拖到屏幕外。
   */
  private fittedSize(scale: number): number[] {
    if (this.sourceWidth <= 0 || this.sourceHeight <= 0 || this.viewWidth <= 0 || this.viewHeight <= 0) {
      return [this.viewWidth * scale, this.viewHeight * scale];
    }
    let ratio = Math.min(this.viewWidth / this.sourceWidth, this.viewHeight / this.sourceHeight);
    return [this.sourceWidth * ratio * scale, this.sourceHeight * ratio * scale];
  }

  private maxOffsetX(scale: number): number {
    return Math.max(0, (this.fittedSize(scale)[0] - this.viewWidth) / 2);
  }

  private maxOffsetY(scale: number): number {
    return Math.max(0, (this.fittedSize(scale)[1] - this.viewHeight) / 2);
  }

  private applyScale(next: number): void {
    this.zoomScale = this.clamp(next, PHOTO_MIN_SCALE, PHOTO_MAX_SCALE);
    if (this.isZoomed()) {
      let limitX = this.maxOffsetX(this.zoomScale);
      let limitY = this.maxOffsetY(this.zoomScale);
      this.panX = this.clamp(this.panX, -limitX, limitX);
      this.panY = this.clamp(this.panY, -limitY, limitY);
    } else {
      // 回到原始倍率时把位移归零，否则图片会停在偏移位置
      this.panX = 0;
      this.panY = 0;
    }
    this.baseScale = this.zoomScale;
    this.basePanX = this.panX;
    this.basePanY = this.panY;
  }

  private handlePinchUpdate(event: GestureEvent): void {
    if (event.scale <= 0) return;
    this.applyScale(this.baseScale * event.scale);
  }

  private handlePinchEnd(): void {
    this.baseScale = this.zoomScale;
    this.basePanX = this.panX;
    this.basePanY = this.panY;
  }

  private handlePanUpdate(event: GestureEvent): void {
    if (!this.isZoomed()) return;
    let limitX = this.maxOffsetX(this.zoomScale);
    let limitY = this.maxOffsetY(this.zoomScale);
    this.panX = this.clamp(this.basePanX + event.offsetX, -limitX, limitX);
    this.panY = this.clamp(this.basePanY + event.offsetY, -limitY, limitY);
  }

  private handlePanEnd(): void {
    this.basePanX = this.panX;
    this.basePanY = this.panY;
  }

  private handleDoubleTap(): void {
    this.applyScale(this.isZoomed() ? PHOTO_MIN_SCALE : PHOTO_DOUBLE_TAP_SCALE);
  }

  build() {
    Column() {
      Row() {
        Text('查看图片')
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White);
        Blank();
        if (this.isZoomed()) {
          Text('还原')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 8 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('还原图片大小')
            .onClick(() => this.applyScale(PHOTO_MIN_SCALE));
        }
        Text('关闭')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭图片全屏预览')
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 });

      if (this.uri.length > 0) {
        Stack() {
          Image(this.uri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.zoomScale, y: this.zoomScale })
            .translate({ x: this.panX, y: this.panY })
            .accessibilityRole(AccessibilityRoleType.IMAGE)
            .accessibilityText('作业照片大图，可双指缩放、双击放大或还原')
            .onComplete((event) => {
              // 拿到图片原始像素尺寸后换算成 vp，用于精确限制拖动边界
              if (event && event.width > 0 && event.height > 0) {
                this.sourceWidth = this.getUIContext().px2vp(event.width);
                this.sourceHeight = this.getUIContext().px2vp(event.height);
              }
            })
            .gesture(
              GestureGroup(GestureMode.Parallel,
                PinchGesture({ fingers: 2 })
                  .onActionUpdate((event: GestureEvent) => this.handlePinchUpdate(event))
                  .onActionEnd(() => this.handlePinchEnd()),
                PanGesture({ fingers: 1 })
                  .onActionUpdate((event: GestureEvent) => this.handlePanUpdate(event))
                  .onActionEnd(() => this.handlePanEnd()),
                TapGesture({ count: 2 })
                  .onAction(() => this.handleDoubleTap())
              )
            );
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Black)
        .clip(true)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.viewWidth = newValue.width as number;
          this.viewHeight = newValue.height as number;
        });

        Text(this.isZoomed() ? '双指继续缩放 · 单指拖动查看细节 · 双击还原' : '双指缩放或双击放大，查看作业细节')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(Color.White)
          .opacity(0.7)
          .padding({ top: 8, bottom: 16, left: 16, right: 16 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black);
  }
}
