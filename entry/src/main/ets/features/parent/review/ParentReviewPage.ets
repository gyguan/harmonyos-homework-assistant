import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { ParentReviewPane } from './ParentReviewPane';

@Component
export struct ParentReviewPage {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onReviewed: () => void = () => {};
  onDeleted: () => void = () => {};

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '作业详情',
          backAccessibilityText: '返回上一页',
          onBack: () => this.onBack()
        });
        Scroll() {
          Column() {
            ParentReviewPane({
              assignmentId: this.assignmentId,
              revision: this.revision,
              onReviewed: () => this.onReviewed(),
              onDeleted: () => this.onDeleted()
            });
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
