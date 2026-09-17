import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { HomeworkImportPage } from './HomeworkImportPage';

@Component
export struct HomeworkImportRoutePage {
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  onStoreChanged: () => void = () => {};

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '导入老师作业',
        subtitle: '老师原文 → 小伴整理 → 家长确认发布',
        backAccessibilityText: '返回家长首页',
        onBack: () => this.onBack()
      });
      Column() {
        HomeworkImportPage({
          revision: this.revision,
          onOpenConfirmation: () => this.onOpenConfirmation(),
          onStoreChanged: () => this.onStoreChanged()
        });
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: AppTheme.DEEP_PAGE_TOP_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
