import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, ActionButtonSize, TextAction, TextActionKind } from '../action/ActionControls';
import { SegmentedSelectionButton } from '../selection/SelectionControls';
import {
  PracticePassFilter,
  PracticeTaxonomy
} from '../../domain/model/practice/PracticeModels';
import {
  PracticeHistorySubjectFilter,
  PracticeHistoryTimeFilter
} from '../../domain/model/PracticeHistoryFilter';

@CustomDialog
export struct PracticeHistoryFilterDialog {
  controller: CustomDialogController;
  @Link selectedSubject: PracticeHistorySubjectFilter;
  @Link selectedTime: PracticeHistoryTimeFilter;
  @Link selectedPass: PracticePassFilter;
  @Prop showSubject: boolean = true;
  onApply: (
    subject: PracticeHistorySubjectFilter,
    time: PracticeHistoryTimeFilter,
    pass: PracticePassFilter
  ) => void =
    (_subject: PracticeHistorySubjectFilter, _time: PracticeHistoryTimeFilter, _pass: PracticePassFilter) => {};
  private subjectLabel(value: PracticeHistorySubjectFilter): string {
    if (value === PracticeHistorySubjectFilter.CHINESE) return '语文';
    if (value === PracticeHistorySubjectFilter.MATH) return '数学';
    if (value === PracticeHistorySubjectFilter.ENGLISH) return '英语';
    return '全部科目';
  }

  private timeLabel(value: PracticeHistoryTimeFilter): string {
    if (value === PracticeHistoryTimeFilter.LAST_7_DAYS) return '近7天';
    if (value === PracticeHistoryTimeFilter.LAST_30_DAYS) return '近30天';
    if (value === PracticeHistoryTimeFilter.LAST_90_DAYS) return '近90天';
    return '全部时间';
  }

  @Builder
  private SubjectOption(value: PracticeHistorySubjectFilter) {
    SegmentedSelectionButton({
      label: this.subjectLabel(value),
      selected: this.selectedSubject === value,
      onSelect: () => this.selectedSubject = value
    })
    .layoutWeight(1);
  }

  @Builder
  private TimeOption(value: PracticeHistoryTimeFilter) {
    SegmentedSelectionButton({
      label: this.timeLabel(value),
      selected: this.selectedTime === value,
      onSelect: () => this.selectedTime = value
    })
    .layoutWeight(1);
  }

  @Builder
  private PassOption(value: PracticePassFilter) {
    SegmentedSelectionButton({
      label: PracticeTaxonomy.passFilterLabel(value),
      selected: this.selectedPass === value,
      onSelect: () => this.selectedPass = value
    })
    .layoutWeight(1);
  }

  private reset(): void {
    this.selectedSubject = PracticeHistorySubjectFilter.ALL;
    this.selectedTime = PracticeHistoryTimeFilter.ALL;
    this.selectedPass = PracticePassFilter.ALL;
  }

  private confirm(): void {
    this.onApply(this.selectedSubject, this.selectedTime, this.selectedPass);
  }

  build() {
    Column() {
      Row() {
        Text('筛选练习记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭练习记录筛选',
          onAction: (): void => this.controller.close()
        });
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 22 }) {
          if (this.showSubject) {
            Column({ space: 10 }) {
              Text('科目')
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Row({ space: 8 }) {
                this.SubjectOption(PracticeHistorySubjectFilter.ALL);
                this.SubjectOption(PracticeHistorySubjectFilter.CHINESE);
              }
              .width('100%');
              Row({ space: 8 }) {
                this.SubjectOption(PracticeHistorySubjectFilter.MATH);
                this.SubjectOption(PracticeHistorySubjectFilter.ENGLISH);
              }
              .width('100%');
            }
            .width('100%');
          }

          Column({ space: 10 }) {
            Text('时间')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.TimeOption(PracticeHistoryTimeFilter.ALL);
              this.TimeOption(PracticeHistoryTimeFilter.LAST_7_DAYS);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.TimeOption(PracticeHistoryTimeFilter.LAST_30_DAYS);
              this.TimeOption(PracticeHistoryTimeFilter.LAST_90_DAYS);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('通过状态')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.PassOption(PracticePassFilter.ALL);
              this.PassOption(PracticePassFilter.PASSED);
              this.PassOption(PracticePassFilter.NOT_PASSED);
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
    .height('58%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
