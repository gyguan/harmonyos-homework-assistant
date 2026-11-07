import { AppTheme } from '../../common/theme/AppTheme';

const PHOTO_MIN_SCALE: number = 1;
const PHOTO_MAX_SCALE: number = 4;
const PHOTO_DOUBLE_TAP_SCALE: number = 2.5;
const PHOTO_SCALE_EPSILON: number = 0.001;
// 双指缩放灵敏度：1 = 完全按手指张开的真实比例
const PHOTO_PINCH_GAIN: number = 1;
// 双指缩放死区：两指间距变化在这个比例内一律不缩放。
// 双指平移时看到两指间距必然有 ±2~4% 抖动，没有死区就会边拖边慢慢变小。
const PHOTO_PINCH_DEAD_ZONE: number = 0.06;
// 松手时低于这个倍率吸附回 1x，避免停在 1.04 这种「半放大」的尴尬状态
const PHOTO_SNAP_SCALE: number = 1.08;
// 拖动越界时最多能拖出图片边缘的比例（橡皮筋阻力）
const PHOTO_PAN_OVERSHOOT: number = 0.45;
// 单指起手容差：轻点画面不会让图片抖动
const PHOTO_TOUCH_SLOP: number = 2;
const PHOTO_TRANSITION_MS: number = 220;

/**
 * 图片大图预览，支持双指缩放、单指拖动、双击放大/还原。
 *
 * 手势没有使用系统的 PinchGesture / PanGesture，改为自己处理 TouchEvent，原因是：
 * 1. 组件一旦带 scale 变换，系统给 PanGesture 的 offset 会按缩放比例被压缩，
 *    放大后拖动只有手指位移的 1/scale——表现出来就是「放大后越拖越慢」；
 * 2. PinchGesture 一旦两指落屏就持续工作，双指平移时两指间距的自然抖动会被当成缩放，
 *    表现出来就是「左右移动时莫名变小」。
 * 自己算就绕开这两点：位移取触摸点坐标差（视口坐标系、不受 scale 影响），
 * 缩放只在两指间距变化超过死区时才生效，单指永远不会改变倍率。
 *
 * 变换分两层：外层只做 translate（自身无 scale，位移是真实 vp），
 * 内层 Image 只做 scale，避免 translate 与 scale 的坐标系耦合。
 */
@CustomDialog
export struct PhotoPreviewDialog {
  controller: CustomDialogController;
  @Link @Watch('onUriChanged') uri: string;

  @State private zoomScale: number = PHOTO_MIN_SCALE;
  @State private panX: number = 0;
  @State private panY: number = 0;

  // 当前手势类型：0=无 1=单指拖动 2=双指缩放
  private gestureMode: number = 0;
  // 单指拖动的基准：起手坐标与起手位移
  private startTouchX: number = 0;
  private startTouchY: number = 0;
  private startPanX: number = 0;
  private startPanY: number = 0;
  // 双指缩放的基准：起手倍率、起手两指间距，以及上一帧的两指中点（相对视口中心）
  private pinchStartScale: number = PHOTO_MIN_SCALE;
  private pinchStartDistance: number = 0;
  private lastAnchorX: number = 0;
  private lastAnchorY: number = 0;
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
    this.gestureMode = 0;
    this.startPanX = 0;
    this.startPanY = 0;
    this.pinchStartScale = PHOTO_MIN_SCALE;
    this.pinchStartDistance = 0;
    this.lastAnchorX = 0;
    this.lastAnchorY = 0;
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

  /** 越界阻尼：范围内 1:1 跟手，越界后按双曲线衰减，拖不飞也拖不僵。 */
  private rubberBand(value: number, limit: number): number {
    if (limit <= 0) return 0;
    let distance = Math.abs(value);
    if (distance <= limit) return value;
    let over = distance - limit;
    let room = limit * PHOTO_PAN_OVERSHOOT;
    return value > 0
      ? limit + room * (1 - 1 / (over / room + 1))
      : -(limit + room * (1 - 1 / (over / room + 1)));
  }

  private clampPanToBounds(): void {
    if (!this.isZoomed()) {
      this.panX = 0;
      this.panY = 0;
      return;
    }
    let limitX = this.maxOffsetX(this.zoomScale);
    let limitY = this.maxOffsetY(this.zoomScale);
    this.panX = this.clamp(this.panX, -limitX, limitX);
    this.panY = this.clamp(this.panY, -limitY, limitY);
  }

  /** 只在双击、还原、松手回弹时用：带过渡，避免画面瞬间跳变。 */
  private animateTransform(action: () => void): void {
    this.getUIContext().animateTo({ duration: PHOTO_TRANSITION_MS, curve: Curve.FastOutSlowIn }, action);
  }

  /** 单指起手容差：扣掉容差而不是直接丢弃，越过容差后位移仍然连续。 */
  private trackingOffset(raw: number): number {
    if (Math.abs(raw) <= PHOTO_TOUCH_SLOP) return 0;
    return raw > 0 ? raw - PHOTO_TOUCH_SLOP : raw + PHOTO_TOUCH_SLOP;
  }

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.finishGesture();
      return;
    }
    let touches = event.touches;
    if (touches.length >= 2) {
      this.updatePinch(touches[0], touches[1]);
    } else if (touches.length === 1) {
      this.updatePan(touches[0]);
    }
  }

  private updatePan(touch: TouchObject): void {
    if (this.gestureMode !== 1) {
      // 起手（或从双指退回单指）：只记基准，本帧不移动
      this.gestureMode = 1;
      this.startTouchX = touch.x;
      this.startTouchY = touch.y;
      this.startPanX = this.panX;
      this.startPanY = this.panY;
      return;
    }
    if (!this.isZoomed()) return;
    let dx = this.trackingOffset(touch.x - this.startTouchX);
    let dy = this.trackingOffset(touch.y - this.startTouchY);
    // 视口坐标系下的真实位移，1:1 跟手，不经过任何缩放换算
    this.panX = this.rubberBand(this.startPanX + dx, this.maxOffsetX(this.zoomScale));
    this.panY = this.rubberBand(this.startPanY + dy, this.maxOffsetY(this.zoomScale));
  }

  private updatePinch(first: TouchObject, second: TouchObject): void {
    let spanX = first.x - second.x;
    let spanY = first.y - second.y;
    let distance = Math.sqrt(spanX * spanX + spanY * spanY);
    let anchorX = (first.x + second.x) / 2 - this.viewWidth / 2;
    let anchorY = (first.y + second.y) / 2 - this.viewHeight / 2;

    if (this.gestureMode !== 2 || this.pinchStartDistance <= 0) {
      // 起手（或从单指变双指）：只记基准，本帧不缩放
      this.gestureMode = 2;
      this.pinchStartScale = this.zoomScale;
      this.pinchStartDistance = distance > 0 ? distance : 1;
      this.lastAnchorX = anchorX;
      this.lastAnchorY = anchorY;
      return;
    }

    // 1) 目标倍率：两指间距变化必须超过死区才动，抖动全部落进死区被吃掉
    let target = this.pinchStartScale;
    let factor = distance / this.pinchStartDistance;
    let delta = factor - 1;
    let magnitude = Math.abs(delta) - PHOTO_PINCH_DEAD_ZONE;
    if (magnitude > 0) {
      let gained = 1 + (delta > 0 ? magnitude : -magnitude) * PHOTO_PINCH_GAIN;
      target = this.clamp(this.pinchStartScale * gained, PHOTO_MIN_SCALE, PHOTO_MAX_SCALE);
    }

    // 2) 以两指中点为锚点缩放：放大时手指下的内容不会跑开，同时中点位移直接当作平移
    let ratio = this.zoomScale > 0 ? target / this.zoomScale : 1;
    let nextPanX = this.panX * ratio + this.lastAnchorX * (1 - ratio) + (anchorX - this.lastAnchorX);
    let nextPanY = this.panY * ratio + this.lastAnchorY * (1 - ratio) + (anchorY - this.lastAnchorY);
    this.zoomScale = target;
    this.lastAnchorX = anchorX;
    this.lastAnchorY = anchorY;

    if (!this.isZoomed()) {
      this.panX = 0;
      this.panY = 0;
      return;
    }
    this.panX = this.rubberBand(nextPanX, this.maxOffsetX(target));
    this.panY = this.rubberBand(nextPanY, this.maxOffsetY(target));
  }

  private finishGesture(): void {
    let wasPinching = this.gestureMode === 2;
    this.gestureMode = 0;
    this.pinchStartDistance = 0;
    let target = this.zoomScale;
    if (target < PHOTO_SNAP_SCALE) target = PHOTO_MIN_SCALE;
    let overflow = Math.abs(this.panX) > this.maxOffsetX(this.zoomScale) + PHOTO_SCALE_EPSILON ||
      Math.abs(this.panY) > this.maxOffsetY(this.zoomScale) + PHOTO_SCALE_EPSILON ||
      target !== this.zoomScale;
    if (wasPinching || overflow) {
      this.animateTransform(() => {
        this.zoomScale = target;
        this.clampPanToBounds();
      });
    }
  }

  private handleDoubleTap(): void {
    let target = this.isZoomed() ? PHOTO_MIN_SCALE : PHOTO_DOUBLE_TAP_SCALE;
    this.animateTransform(() => {
      this.zoomScale = target;
      this.clampPanToBounds();
    });
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
            .onClick(() => this.handleDoubleTap());
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
        // 视口层：只负责裁剪、接收触摸、取尺寸。它自身永远不带 scale/translate，
        // 所以触摸点坐标与 viewWidth/viewHeight 始终是同一个（稳定）坐标系。
        Stack() {
          // 平移层：自身没有 scale，translate 就是真实屏幕 vp
          Stack() {
            // 缩放层
            Image(this.uri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({ x: this.zoomScale, y: this.zoomScale })
              .accessibilityRole(AccessibilityRoleType.IMAGE)
              .accessibilityText('作业照片大图，可双指缩放、双击放大或还原')
              .onComplete((event) => {
                // 拿到图片原始像素尺寸后换算成 vp，用于精确限制拖动边界
                if (event && event.width > 0 && event.height > 0) {
                  this.sourceWidth = this.getUIContext().px2vp(event.width);
                  this.sourceHeight = this.getUIContext().px2vp(event.height);
                }
              });
          }
          .width('100%')
          .height('100%')
          .translate({ x: this.panX, y: this.panY });
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Black)
        .clip(true)
        .onTouch((event: TouchEvent) => this.handleTouch(event))
        .gesture(
          TapGesture({ count: 2 })
            .onAction(() => this.handleDoubleTap())
        )
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
