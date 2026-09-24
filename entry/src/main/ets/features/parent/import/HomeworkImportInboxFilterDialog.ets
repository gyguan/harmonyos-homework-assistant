import { AppTheme } from '../../../common/theme/AppTheme';
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
    Button(HomeworkImportInboxFilterLabels.source(filter), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedSource === filter ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedSource === filter ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedSource === filter ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedSource = filter);
  }

  @Builder
  private StatusOption(filter: HomeworkImportInboxStatusFilter) {
    Button(HomeworkImportInboxFilterLabels.status(filter), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedStatus === filter ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedStatus === filter ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedStatus === filter ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedStatus = filter);
  }

  @Builder
  private TimeOption(filter: HomeworkImportInboxTimeFilter) {
    Button(HomeworkImportInboxFilterLabels.time(filter), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedTime === filter ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedTime === filter ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedTime === filter ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedTime = filter);
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
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('关闭')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭收件箱筛选')
          .onClick(() => this.controller.close());
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
        Button('重置', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.reset());
        Button('确定', { type: ButtonType.Normal })
          .layoutWeight(2)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.confirm());
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
