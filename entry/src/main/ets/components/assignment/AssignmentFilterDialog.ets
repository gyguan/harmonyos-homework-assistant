import { AppTheme } from '../../common/theme/AppTheme';

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
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(14)
      .fontWeight(this.allDates === allDates ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.allDates === allDates ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.allDates === allDates ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.allDates = allDates);
  }

  @Builder
  private SubjectOption(label: string, value: string) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(14)
      .fontWeight(this.subjectCode === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.subjectCode === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.subjectCode === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.subjectCode = value);
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
          .accessibilityText('关闭作业查询')
          .onClick(() => this.controller.close());
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
        Button('重置', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.reset());
        Button('查询', { type: ButtonType.Normal })
          .layoutWeight(2)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.confirmQuery());
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
