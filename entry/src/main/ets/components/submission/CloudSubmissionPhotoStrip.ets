import { RemoteSubmissionApi, RemoteSubmissionResource } from '../../application/remote/RemoteSubmissionApi';
import { AppTheme } from '../../common/theme/AppTheme';
import { PhotoPreviewDialog } from './PhotoPreviewDialog';

/** 86vp 的格子按 3x 屏需要 258px，取 320 给一点余量。 */
const THUMBNAIL_WIDTH: number = 320;

@Component
export struct CloudSubmissionPhotoStrip {
  @Prop @Watch('onPhotosChanged') photos: RemoteSubmissionResource[];
  @State private cacheRevision: number = 0;
  @State private loadingCount: number = 0;
  @State private previewUri: string = '';
  private previewPhotoId: string = '';

  private previewController: CustomDialogController = new CustomDialogController({
    builder: PhotoPreviewDialog({
      uri: $previewUri,
      // 大图弹窗先用缩略图打开，原图在后台下载，到货后由弹窗自己在空闲时替换。
      loadFullImage: () => this.loadFullImageForPreview()
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    void this.loadMissingPhotos();
  }

  onPhotosChanged(): void {
    void this.loadMissingPhotos();
  }

  private thumbnailUri(photoId: string): string {
    // 读一下 revision 建立依赖收集：缩略图下载完成后 build 才会重新取 URI。
    let currentRevision = this.cacheRevision;
    return RemoteSubmissionApi.instance.cachedThumbnailUri(photoId, THUMBNAIL_WIDTH);
  }

  /**
   * 每个格子只要一张 320px 的缩略图（约 20KB），而不是 2~3MB 的原图：
   * 服务器出口约 3Mbps，原图一张就要 8 秒，缩略图几十毫秒。
   * 缩略图之间互不依赖，并发拉取，谁先到谁先显示。
   */
  private async loadMissingPhotos(): Promise<void> {
    let tasks: Promise<void>[] = [];
    for (let photo of this.photos) {
      if (this.thumbnailUri(photo.id).length > 0) continue;
      tasks.push(this.loadThumbnail(photo));
    }
    if (tasks.length === 0) return;
    await Promise.all(tasks);
  }

  private async loadThumbnail(photo: RemoteSubmissionResource): Promise<void> {
    this.loadingCount++;
    try {
      let uri = await RemoteSubmissionApi.instance.downloadThumbnail(photo, THUMBNAIL_WIDTH);
      if (uri.length > 0) this.cacheRevision++;
    } finally {
      this.loadingCount = Math.max(0, this.loadingCount - 1);
    }
  }

  private openPreview(photo: RemoteSubmissionResource): void {
    let thumbnail = this.thumbnailUri(photo.id);
    let full = RemoteSubmissionApi.instance.cachedPhotoUri(photo.id);
    let initial = thumbnail.length > 0 ? thumbnail : full;
    if (initial.length === 0) return;
    this.previewPhotoId = photo.id;
    this.previewUri = initial;
    this.previewController.open();
  }

  private async loadFullImageForPreview(): Promise<string> {
    for (let photo of this.photos) {
      if (photo.id !== this.previewPhotoId) continue;
      return await RemoteSubmissionApi.instance.downloadPhoto(photo);
    }
    return '';
  }

  build() {
    Column({ space: 7 }) {
      Scroll() {
        Row({ space: 9 }) {
          ForEach(this.photos, (photo: RemoteSubmissionResource) => {
            if (this.thumbnailUri(photo.id).length > 0) {
              Image(this.thumbnailUri(photo.id))
                .width(86)
                .height(86)
                .objectFit(ImageFit.Cover)
                .borderRadius(12)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText('查看作业照片大图')
                .onClick(() => this.openPreview(photo));
            } else {
              Column({ space: 5 }) {
                Text('作业照片')
                  .fontSize(AppTheme.LABEL_TITLE_SIZE)
                  .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TERTIARY_TEXT);
                Text(this.loadingCount > 0 ? '下载中' : '暂不可用')
                  .fontSize(AppTheme.CAPTION_SIZE)
                  .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .width(86)
              .height(86)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .borderRadius(12);
            }
          }, (photo: RemoteSubmissionResource) => photo.id);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      if (this.loadingCount > 0) {
        Text('正在从家庭云端加载照片…').width('100%').fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%');
  }
}
