import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct PracticeQuestionVisual {
  @Prop visualType: string = 'NONE';
  @Prop assetId: string = '';
  @Prop accessibilityText: string = '';

  @Builder
  private VisualImage() {
    if (this.visualType === 'ARRAY') {
      Image($r('app.media.practice_visual_array'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'DOT_ARRAY') {
      Image($r('app.media.practice_visual_dot_array'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'IMAGE_PAIR') {
      Image($r('app.media.practice_visual_image_pair'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'IMAGE_SEQUENCE') {
      Image($r('app.media.practice_visual_sequence'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'DIALOGUE') {
      Image($r('app.media.practice_visual_dialogue'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'ROOM_SCENE') {
      Image($r('app.media.practice_visual_room'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'FAMILY_SCENE') {
      Image($r('app.media.practice_visual_family'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'CHARACTER') {
      Image($r('app.media.practice_visual_character'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else if (this.visualType === 'ILLUSTRATION') {
      Image($r('app.media.practice_visual_illustration'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    } else {
      Image($r('app.media.practice_visual_scene'))
        .width('100%').height(180).objectFit(ImageFit.Contain);
    }
  }

  build() {
    Column({ space: 8 }) {
      this.VisualImage();
      if (this.accessibilityText.length > 0) {
        Text(this.accessibilityText)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityText(this.accessibilityText.length > 0 ? this.accessibilityText : '题目配图');
  }
}
