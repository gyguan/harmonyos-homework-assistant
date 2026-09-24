import { AppTheme } from '../../common/theme/AppTheme';
import { TextAction, TextActionKind } from '../action/ActionControls';

@Component
export struct EditSheetHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop closeAccessibilityText: string = '关闭';
  onClose: () => void = () => {};

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .maxLines(1)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      TextAction({
        label: '关闭',
        kind: TextActionKind.NEUTRAL,
        accessibilityLabel: this.closeAccessibilityText,
        onAction: () => this.onClose()
      });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 });
  }
}
