import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, TextAction, TextActionKind } from '../action/ActionControls';
import { SegmentedSelectionButton } from '../selection/SelectionControls';

@CustomDialog
export struct AssignmentFilterDialog {
  controller: CustomDialogController;
  @Link allDates: boolean;
  @Link selectedDayEpochMs: number;
  @Link subjectCode: string;
  onQuery: (allDates: boolean, selectedDayEpochMs: number, subjectCode: string) => void =
    (_allDates: boolean, _selectedDayEpochMs: number, _subjectCode: string) => {};

  @Builder
  private DateModeOption(label: string, allDates: boolean) {
    SegmentedSelectionButton({
      label: label,
      selected: this.allDates === allDates,
      onSelect: () => this.allDates = allDates
    })
    .layoutWeight(1);
  }

  @Builder
  private SubjectOption(label: string, value: string) {
    SegmentedSelectionButton({
      label: label,
      selected: this.subjectCode === value,
      onSelect: () => this.subjectCode = value
    })
    .layoutWeight(1);
  }

  private reset(): void {
    let now = new Date();
    this.allDates = false;
    this.selectedDayEpochMs = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    this.subjectCode = 'ALL';
  }

  private confirmQuery(): void {
    this.onQuery(this.allDates, this.selectedDayEpochMs, this.subjectCode);
  }

  build() {
    Column() {
      Row() {
        Text('查询作业')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭作业查询',
          onAction: () => this.controller.close()
        });
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Text('日期').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.DateModeOption('全部日期', true);
              this.DateModeOption('指定日期', false);
            }
            .width('100%');
            if (!this.allDates) {
              DatePicker({ selected: new Date(this.selectedDayEpochMs) })
                .width('100%')
                .height(170)
                .lunar(false)
                .onDateChange((value: Date) => {
                  this.selectedDayEpochMs =
                    new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
                });
            }
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('科目').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.SubjectOption('全部科目', 'ALL');
              this.SubjectOption('语文', 'CHINESE');
              this.SubjectOption('数学', 'MATH');
            }
            .width('100%');
            Row({ space: 8 }) {
              this.SubjectOption('英语', 'ENGLISH');
              this.SubjectOption('其他', 'OTHER');
              Blank().layoutWeight(1);
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
          onAction: () => this.reset()
        })
        .layoutWeight(1);
        ActionButton({
          label: '查询',
          onAction: () => this.confirmQuery()
        })
        .layoutWeight(2);
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 18 })
      .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .height('62%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
