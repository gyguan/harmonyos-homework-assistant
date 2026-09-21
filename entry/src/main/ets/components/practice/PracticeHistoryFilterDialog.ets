import { AppTheme } from '../../common/theme/AppTheme';
import {
  PracticePassFilter,
  PracticeTaxonomy
} from '../../domain/model/practice/PracticeModels';
import {
  PracticeHistorySubjectFilter,
  PracticeHistoryTimeFilter
} from '../../features/student/practice/PracticeHistoryViewModel';

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
    Button(this.subjectLabel(value), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedSubject === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedSubject === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedSubject === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedSubject = value);
  }

  @Builder
  private TimeOption(value: PracticeHistoryTimeFilter) {
    Button(this.timeLabel(value), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedTime === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedTime === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedTime === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedTime = value);
  }

  @Builder
  private PassOption(value: PracticePassFilter) {
    Button(PracticeTaxonomy.passFilterLabel(value), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedPass === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedPass === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedPass === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedPass = value);
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
        Text('关闭')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭练习记录筛选')
          .onClick(() => this.controller.close());
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
    .height('58%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
