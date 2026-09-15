import { RemoteSubmissionApi, RemoteSubmissionPhoto } from '../../application/remote/RemoteSubmissionApi';
import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct CloudSubmissionPhotoStrip {
  @Prop photos: RemoteSubmissionPhoto[];
  @State private cacheRevision: number = 0;
  @State private loading: boolean = false;

  aboutToAppear(): void {
    void this.loadMissingPhotos();
  }

  private photoUri(photoId: string): string {
    let currentRevision = this.cacheRevision;
    return RemoteSubmissionApi.instance.cachedPhotoUri(photoId);
  }

  private async loadMissingPhotos(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    try {
      for (let photo of this.photos) {
        if (RemoteSubmissionApi.instance.cachedPhotoUri(photo.id).length > 0) continue;
        let uri = await RemoteSubmissionApi.instance.downloadPhoto(photo);
        if (uri.length > 0) this.cacheRevision++;
      }
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column({ space: 7 }) {
      Scroll() {
        Row({ space: 9 }) {
          ForEach(this.photos, (photo: RemoteSubmissionPhoto) => {
            if (this.photoUri(photo.id).length > 0) {
              Image(this.photoUri(photo.id))
                .width(86)
                .height(86)
                .objectFit(ImageFit.Cover)
                .borderRadius(12)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS);
            } else {
              Column({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.photo'))
                  .fontSize(22)
                  .fontColor([AppTheme.TERTIARY_TEXT]);
                Text(this.loading ? '下载中' : '暂不可用')
                  .fontSize(10)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .width(86)
              .height(86)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .borderRadius(12);
            }
          }, (photo: RemoteSubmissionPhoto) => photo.id);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      if (this.loading) {
        Text('正在从家庭云端加载照片…').width('100%').fontSize(11).fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%');
  }
}
