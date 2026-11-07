import { AppTheme } from '../../common/theme/AppTheme';

const PHOTO_MIN_SCALE: number = 1;
const PHOTO_MAX_SCALE: number = 4;
const PHOTO_DOUBLE_TAP_SCALE: number = 2.5;
const PHOTO_SCALE_EPSILON: number = 0.001;
// 双指灵敏度：手势累计倍率的增量乘这个系数，轻微捏合不会一上手就跳一大截
const PHOTO_PINCH_GAIN: number = 0.9;
// 双指缩放死区：两指间距变化在这个比例内一律不缩放。
// 双指平移时两指间距必然有 ±2~4% 抖动，没有死区就会边拖边慢慢缩小。
const PHOTO_PINCH_DEAD_ZONE: number = 0.05;
// 单指拖动识别阈值，越小越跟手（旧值 10 起步有明显「拖不动」的迟滞）
const PHOTO_PAN_DISTANCE: number = 1;
const PHOTO_PINCH_DISTANCE: number = 8;
// 松手时低于这个倍率吸附回 1x，避免停在 1.04 这种「半放大」的尴尬状态
const PHOTO_SNAP_SCALE: number = 1.08;
// 捏合超过上限时允许的视觉溢出比例，松手再动画收回上限（软限制，不是硬砍）
const PHOTO_OVERSCALE_RATIO: number = 0.12;
// 拖动越界时最多能拖出图片边缘的比例（橡皮筋阻力）
const PHOTO_PAN_OVERSHOOT: number = 0.45;
const PHOTO_TRANSITION_MS: number = 220;

@CustomDialog
export struct PhotoPreviewDialog {
  controller: CustomDialogController;
  @Link @Watch('onUriChanged') uri: string;

  @State private zoomScale: number = PHOTO_MIN_SCALE;
  @State private panX: number = 0;
  @State private panY: number = 0;
  // 手势开始那一刻的基准值。只在 onActionStart 记录，手势过程中绝不能被覆盖：
  // event.scale / event.offsetX 都是「本次手势的累计值」，一旦每帧回写基准就会连乘。
  private gestureStartScale: number = PHOTO_MIN_SCALE;
  private gestureStartPanX: number = 0;
  private gestureStartPanY: number = 0;
  // 手势被识别那一刻事件里已有的累计量（distance 阈值吃掉的起步位移/倍率），
  // 后面每帧减掉它，才能让图片从手指按下的位置开始跟手，而不是先跳一下。
  private pinchStartFactor: number = 1;
  private panStartOffsetX: number = 0;
  private panStartOffsetY: number = 0;
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
    this.gestureStartScale = PHOTO_MIN_SCALE;
    this.gestureStartPanX = 0;
    this.gestureStartPanY = 0;
    this.pinchStartFactor = 1;
    this.panStartOffsetX = 0;
    this.panStartOffsetY = 0;
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

  /** 超过上限后的软限制：越捏越沉，最多只溢出 PHOTO_OVERSCALE_RATIO，松手再收回。 */
  private softUpperLimit(raw: number): number {
    if (raw <= PHOTO_MAX_SCALE) return raw;
    let over = raw - PHOTO_MAX_SCALE;
    let cap = PHOTO_MAX_SCALE * PHOTO_OVERSCALE_RATIO;
    return PHOTO_MAX_SCALE + cap * (1 - 1 / (over / cap + 1));
  }

  /** 越界阻尼：范围内 1:1 跟手，越界后按双曲线衰减，拖不飞也拖不僵。 */
  private rubberBand(value: number, limit: number): number {
    if (limit <= 0) return 0;
    let distance = Math.abs(value);
    if (distance <= limit) return value;
    let over = distance - limit;
    let room = limit * PHOTO_PAN_OVERSHOOT;
    let damped = limit + room * (1 - 1 / (over / room + 1));
    return value > 0 ? damped : -damped;
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

  private handlePinchStart(event: GestureEvent): void {
    this.gestureStartScale = this.zoomScale;
    // 手势识别时 event.scale 可能已经不是 1（PinchGesture 有 distance 阈值），
    // 用它做起点，后续按相对比例算，起步就不会突然缩/放一下。
    this.pinchStartFactor = (event && event.scale > 0) ? event.scale : 1;
  }

  private handlePinchUpdate(event: GestureEvent): void {
    if (!event || event.scale <= 0) return;
    let relative = event.scale / this.pinchStartFactor;
    let delta = relative - 1;
    // 死区：双指平移时两指间距的轻微抖动落在这里，图片不会跟着一缩一放
    let magnitude = Math.abs(delta) - PHOTO_PINCH_DEAD_ZONE;
    if (magnitude <= 0) return;
    let gained = 1 + (delta > 0 ? magnitude : -magnitude) * PHOTO_PINCH_GAIN;
    let raw = this.gestureStartScale * gained;
    this.zoomScale = Math.max(PHOTO_MIN_SCALE, this.softUpperLimit(raw));
    // 缩放途中位移只做柔性收敛，别每帧硬砍（硬砍会顿挫）
    this.panX = this.rubberBand(this.panX, this.maxOffsetX(this.zoomScale));
    this.panY = this.rubberBand(this.panY, this.maxOffsetY(this.zoomScale));
  }

  private handlePinchEnd(): void {
    let target = this.zoomScale;
    if (target > PHOTO_MAX_SCALE) {
      target = PHOTO_MAX_SCALE;
    } else if (target < PHOTO_SNAP_SCALE) {
      target = PHOTO_MIN_SCALE;
    }
    this.animateTransform(() => {
      this.zoomScale = target;
      this.clampPanToBounds();
    });
  }

  private handlePanStart(event: GestureEvent): void {
    this.gestureStartPanX = this.panX;
    this.gestureStartPanY = this.panY;
    this.panStartOffsetX = event ? event.offsetX : 0;
    this.panStartOffsetY = event ? event.offsetY : 0;
  }

  private handlePanUpdate(event: GestureEvent): void {
    if (!this.isZoomed()) return;
    // 双指落屏时交给 PinchGesture，别让两指的平均位移也来抢拖动（会和缩放互相拉扯）
    if (event.fingerList !== undefined && event.fingerList.length > 1) return;
    // 减掉手势识别前被 distance 阈值吃掉的位移，图片才从手指按下的位置开始跟手
    let dx = event.offsetX - this.panStartOffsetX;
    let dy = event.offsetY - this.panStartOffsetY;
    this.panX = this.rubberBand(this.gestureStartPanX + dx, this.maxOffsetX(this.zoomScale));
    this.panY = this.rubberBand(this.gestureStartPanY + dy, this.maxOffsetY(this.zoomScale));
  }

  private handlePanEnd(): void {
    // 只有真的越界才播回弹，范围内松手不该有附加动画（会显得拖不动、黏手）
    if (Math.abs(this.panX) > this.maxOffsetX(this.zoomScale) ||
      Math.abs(this.panY) > this.maxOffsetY(this.zoomScale)) {
      this.animateTransform(() => this.clampPanToBounds());
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
                PinchGesture({ fingers: 2, distance: PHOTO_PINCH_DISTANCE })
                  .onActionStart((event: GestureEvent) => this.handlePinchStart(event))
                  .onActionUpdate((event: GestureEvent) => this.handlePinchUpdate(event))
                  .onActionEnd(() => this.handlePinchEnd())
                  .onActionCancel(() => this.handlePinchEnd()),
                PanGesture({ fingers: 1, distance: PHOTO_PAN_DISTANCE })
                  .onActionStart((event: GestureEvent) => this.handlePanStart(event))
                  .onActionUpdate((event: GestureEvent) => this.handlePanUpdate(event))
                  .onActionEnd(() => this.handlePanEnd())
                  .onActionCancel(() => this.handlePanEnd()),
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
