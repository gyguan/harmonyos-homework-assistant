import { AppTheme } from '../../common/theme/AppTheme';
import { AssignmentDueDate } from '../../domain/service/AssignmentDueDate';

@CustomDialog
export struct DeadlinePickerDialog {
  controller: CustomDialogController;
  @Link selectedDate: Date;
  @Link selectedTime: Date;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('选择截止时间')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text('关闭')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭截止时间选择')
          .onClick(() => this.controller.close());
      }
      .width('100%');

      Column({ space: 6 }) {
        Text('日期').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        DatePicker({
          start: new Date(),
          end: new Date(new Date().getFullYear() + 3, 11, 31),
          selected: this.selectedDate
        })
          .width('100%')
          .height(170)
          .lunar(false)
          .onDateChange((value: Date) => {
            this.selectedDate = value;
          });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      Column({ space: 6 }) {
        Text('时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
        TimePicker({ selected: this.selectedTime })
          .width('100%')
          .height(130)
          .useMilitaryTime(true)
          .onChange((value: TimePickerResult) => {
            let next = new Date(this.selectedTime.getTime());
            next.setHours(value.hour, value.minute, 0, 0);
            this.selectedTime = next;
          });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      Button('确定', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          this.onConfirm();
          this.controller.close();
        });
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .padding({ left: 20, right: 20, top: 20, bottom: 18 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}

@Component
export struct DeadlinePickerField {
  @Prop value: string = '';
  @Prop allowClear: boolean = true;
  @State private selectedDate: Date = new Date();
  @State private selectedTime: Date = new Date();
  onChange: (value: string) => void = (_value: string) => {};

  private pickerController: CustomDialogController = new CustomDialogController({
    builder: DeadlinePickerDialog({
      selectedDate: $selectedDate,
      selectedTime: $selectedTime,
      onConfirm: () => this.commitSelection()
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private openPicker(): void {
    this.prepareSelection();
    this.pickerController.open();
  }

  private prepareSelection(): void {
    let resolved = AssignmentDueDate.resolveDueAtEpochMs(this.value, Date.now());
    if (resolved > 0) {
      let shifted = new Date(resolved + 8 * 60 * 60 * 1000);
      this.selectedDate = new Date(
        shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate());
      this.selectedTime = new Date(
        2000, 0, 1, shifted.getUTCHours(), shifted.getUTCMinutes(), 0, 0);
      return;
    }

    let today = new Date();
    today.setHours(0, 0, 0, 0);
    this.selectedDate = today;
    this.selectedTime = new Date(2000, 0, 1, 20, 0, 0, 0);
  }

  private commitSelection(): void {
    let year = this.selectedDate.getFullYear();
    let month = this.selectedDate.getMonth() + 1;
    let day = this.selectedDate.getDate();
    let hour = this.selectedTime.getHours();
    let minute = this.selectedTime.getMinutes();
    this.onChange(
      `${year}-${this.pad(month)}-${this.pad(day)} ${this.pad(hour)}:${this.pad(minute)}前`);
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  build() {
    Row({ space: 8 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.value.length > 0 ? this.value : '未设置截止时间')
            .width('100%')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.value.length > 0 ? AppTheme.TEXT : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('选择')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.value.length > 0 ? `当前截止时间 ${this.value}，点击修改` : '未设置截止时间，点击选择')
      .onClick(() => this.openPicker());

      if (this.allowClear && this.value.length > 0) {
        Text('清除')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('清除截止时间')
          .onClick(() => this.onChange(''));
      }
    }
    .width('100%');
  }
}
