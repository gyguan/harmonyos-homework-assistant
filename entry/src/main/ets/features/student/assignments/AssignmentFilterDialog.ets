import { AppTheme } from '../../../common/theme/AppTheme';
import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';

@CustomDialog
export struct AssignmentFilterDialog {
  controller: CustomDialogController;
  @Link typeFilter: AssignmentTypeFilter;
  @Link dateFilter: AssignmentDateFilter;
  @Link subjectCode: string;
  onQuery: (typeFilter: AssignmentTypeFilter, dateFilter: AssignmentDateFilter, subjectCode: string) => void =
    (_typeFilter: AssignmentTypeFilter, _dateFilter: AssignmentDateFilter, _subjectCode: string) => {};

  @Builder
  private TypeOption(label: string, value: AssignmentTypeFilter) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(14)
      .fontWeight(this.typeFilter === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.typeFilter === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.typeFilter === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.typeFilter = value);
  }

  @Builder
  private DateOption(label: string, value: AssignmentDateFilter) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(14)
      .fontWeight(this.dateFilter === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.dateFilter === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.dateFilter === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.dateFilter = value);
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
    this.typeFilter = AssignmentTypeFilter.ALL;
    this.dateFilter = AssignmentDateFilter.ALL;
    this.subjectCode = 'ALL';
  }

  private confirmQuery(): void {
    this.onQuery(this.typeFilter, this.dateFilter, this.subjectCode);
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('筛选作业')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('选择条件后点击查询')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text('关闭')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 4 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('关闭筛选')
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Text('类型').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.TypeOption('全部', AssignmentTypeFilter.ALL);
              this.TypeOption('课内', AssignmentTypeFilter.SCHOOL);
              this.TypeOption('课外', AssignmentTypeFilter.EXTRA);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('截止时间').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.DateOption('全部日期', AssignmentDateFilter.ALL);
              this.DateOption('今天', AssignmentDateFilter.TODAY);
              this.DateOption('明天', AssignmentDateFilter.TOMORROW);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.DateOption('本周', AssignmentDateFilter.THIS_WEEK);
              this.DateOption('未定', AssignmentDateFilter.UNDATED);
              Blank().layoutWeight(1);
            }
            .width('100%');
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
    .height('68%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
