import { AppTheme } from '../../common/theme/AppTheme';
import { AssignmentTaskDate } from '../../domain/service/AssignmentTaskDate';

@CustomDialog
export struct TaskDatePickerDialog {
  controller: CustomDialogController;
  @Link selectedDate: Date;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('选择任务日期')
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('关闭')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭任务日期选择')
          .onClick(() => this.controller.close());
      }
      .width('100%');

      DatePicker({
        start: new Date(),
        end: new Date(new Date().getFullYear() + 3, 11, 31),
        selected: this.selectedDate
      })
        .width('100%')
        .height(200)
        .lunar(false)
        .onDateChange((value: Date) => this.selectedDate = value);

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
export struct TaskDatePickerField {
  @Prop value: string = '';
  @State private selectedDate: Date = new Date();
  onChange: (value: string) => void = (_value: string) => {};

  private pickerController: CustomDialogController = new CustomDialogController({
    builder: TaskDatePickerDialog({
      selectedDate: $selectedDate,
      onConfirm: () => this.commitSelection()
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private openPicker(): void {
    let parts = AssignmentTaskDate.parse(this.value);
    this.selectedDate = parts === null ? new Date() :
      new Date(parts.year, parts.month - 1, parts.day);
    this.pickerController.open();
  }

  private commitSelection(): void {
    let year = this.selectedDate.getFullYear();
    let month = this.selectedDate.getMonth() + 1;
    let day = this.selectedDate.getDate();
    this.onChange(`${year}-${this.pad(month)}-${this.pad(day)}`);
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  build() {
    Row() {
      Text(this.value.length > 0 ? AssignmentTaskDate.displayText(this.value) : '请选择任务日期')
        .layoutWeight(1)
        .fontSize(AppTheme.FORM_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.value.length > 0 ? AppTheme.TEXT : AppTheme.SUBTEXT);
      Text('选择')
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.value.length > 0 ? `当前任务日期 ${this.value}，点击修改` : '请选择任务日期')
    .onClick(() => this.openPicker());
  }
}
