import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { AssignmentDetailPane } from './AssignmentDetailPane';

@Component
export struct StudentAssignmentDetailPage {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  build() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
          DeepPageHeader({
            title: '作业详情',
            backAccessibilityText: '返回作业列表',
            onBack: () => this.onBack()
          });
          AssignmentDetailPane({
            assignmentId: this.assignmentId,
            revision: this.revision,
            onOpenStudy: (assignmentId: string) => this.onOpenStudy(assignmentId)
          });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: AppTheme.PAGE_PADDING,
          right: AppTheme.PAGE_PADDING,
          top: AppTheme.DEEP_PAGE_TOP_PADDING,
          bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING
        });
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }
}
