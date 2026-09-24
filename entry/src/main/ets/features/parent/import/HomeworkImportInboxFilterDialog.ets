import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, ActionButtonSize, TextAction, TextActionKind } from '../../../components/action/ActionControls';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import {
  HomeworkImportInboxFilterLabels,
  HomeworkImportInboxSourceFilter,
  HomeworkImportInboxStatusFilter,
  HomeworkImportInboxTimeFilter
} from './HomeworkImportInboxFilters';

@CustomDialog
export struct HomeworkImportInboxFilterDialog {
  controller: CustomDialogController;
  @Link selectedSource: HomeworkImportInboxSourceFilter;
  @Link selectedStatus: HomeworkImportInboxStatusFilter;
  @Link selectedTime: HomeworkImportInboxTimeFilter;
  onApply: (
    source: HomeworkImportInboxSourceFilter,
    status: HomeworkImportInboxStatusFilter,
    time: HomeworkImportInboxTimeFilter
  ) => void =
    (_source: HomeworkImportInboxSourceFilter, _status: HomeworkImportInboxStatusFilter,
      _time: HomeworkImportInboxTimeFilter) => {};

  @Builder
  private SourceOption(filter: HomeworkImportInboxSourceFilter) {
    SegmentedSelectionButton({
      label: HomeworkImportInboxFilterLabels.source(filter),
      selected: this.selectedSource === filter,
      onSelect: () => this.selectedSource = filter
    })
    .layoutWeight(1);
  }

  @Builder
  private StatusOption(filter: HomeworkImportInboxStatusFilter) {
    SegmentedSelectionButton({
      label: HomeworkImportInboxFilterLabels.status(filter),
      selected: this.selectedStatus === filter,
      onSelect: () => this.selectedStatus = filter
    })
    .layoutWeight(1);
  }

  @Builder
  private TimeOption(filter: HomeworkImportInboxTimeFilter) {
    SegmentedSelectionButton({
      label: HomeworkImportInboxFilterLabels.time(filter),
      selected: this.selectedTime === filter,
      onSelect: () => this.selectedTime = filter
    })
    .layoutWeight(1);
  }

  private reset(): void {
    this.selectedSource = HomeworkImportInboxSourceFilter.ALL;
    this.selectedStatus = HomeworkImportInboxStatusFilter.ALL;
    this.selectedTime = HomeworkImportInboxTimeFilter.ALL;
  }

  private confirm(): void {
    this.onApply(this.selectedSource, this.selectedStatus, this.selectedTime);
  }

  build() {
    Column() {
      Row() {
        Text('筛选收件箱')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭收件箱筛选',
          onAction: (): void => this.controller.close()
        });
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Text('来源').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.SourceOption(HomeworkImportInboxSourceFilter.ALL);
              this.SourceOption(HomeworkImportInboxSourceFilter.CLIPBOARD);
              this.SourceOption(HomeworkImportInboxSourceFilter.SCREENSHOT);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.SourceOption(HomeworkImportInboxSourceFilter.SHARE);
              this.SourceOption(HomeworkImportInboxSourceFilter.SCREEN_CAPTURE);
              Blank().layoutWeight(1);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('状态').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.StatusOption(HomeworkImportInboxStatusFilter.ALL);
              this.StatusOption(HomeworkImportInboxStatusFilter.READY);
              this.StatusOption(HomeworkImportInboxStatusFilter.PUBLISHED);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.StatusOption(HomeworkImportInboxStatusFilter.RECEIVED);
              this.StatusOption(HomeworkImportInboxStatusFilter.EMPTY);
              this.StatusOption(HomeworkImportInboxStatusFilter.ABANDONED);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('时间').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.TimeOption(HomeworkImportInboxTimeFilter.ALL);
              this.TimeOption(HomeworkImportInboxTimeFilter.TODAY);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.TimeOption(HomeworkImportInboxTimeFilter.LAST_7_DAYS);
              this.TimeOption(HomeworkImportInboxTimeFilter.LAST_30_DAYS);
            }
            .width('100%');
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 18 });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      Row({ space: 12 }) {
        ActionButton({
          label: '重置',
          kind: ActionButtonKind.NEUTRAL,
          size: ActionButtonSize.MEDIUM,
          onAction: (): void => this.reset()
        })
        .layoutWeight(1);
        ActionButton({
          label: '确定',
          size: ActionButtonSize.MEDIUM,
          onAction: (): void => this.confirm()
        })
        .layoutWeight(2);
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 18 })
      .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .height('72%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
