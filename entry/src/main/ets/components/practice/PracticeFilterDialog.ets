import { AppTheme } from '../../common/theme/AppTheme';
import {
  PracticeGrade,
  PracticeSubject,
  PracticeTaxonomy,
  PracticeTrackFilter
} from '../../domain/model/practice/PracticeModels';

@CustomDialog
export struct PracticeFilterDialog {
  controller: CustomDialogController;
  @Link selectedGrade: PracticeGrade;
  @Link selectedSubject: PracticeSubject;
  @Link selectedTrack: PracticeTrackFilter;
  onApply: (grade: PracticeGrade, subject: PracticeSubject, track: PracticeTrackFilter) => void =
    (_grade: PracticeGrade, _subject: PracticeSubject, _track: PracticeTrackFilter) => {};

  @Builder
  private GradeOption(grade: PracticeGrade) {
    Button(PracticeTaxonomy.gradeLabel(grade), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedGrade === grade ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedGrade === grade ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedGrade === grade ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedGrade = grade);
  }

  @Builder
  private SubjectOption(subject: PracticeSubject) {
    Button(PracticeTaxonomy.subjectLabel(subject), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(14)
      .fontWeight(this.selectedSubject === subject ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedSubject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedSubject === subject ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedSubject = subject);
  }

  @Builder
  private TrackOption(track: PracticeTrackFilter) {
    Button(PracticeTaxonomy.trackFilterLabel(track), { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selectedTrack === track ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selectedTrack === track ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selectedTrack === track ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.selectedTrack = track);
  }

  private confirm(): void {
    this.onApply(this.selectedGrade, this.selectedSubject, this.selectedTrack);
  }

  build() {
    Column() {
      Row() {
        Text('筛选练习')
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
          .accessibilityText('关闭练习筛选')
          .onClick(() => this.controller.close());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 });

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Text('年级')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.GradeOption(PracticeGrade.G1);
              this.GradeOption(PracticeGrade.G2);
              this.GradeOption(PracticeGrade.G3);
            }
            .width('100%');
            Row({ space: 8 }) {
              this.GradeOption(PracticeGrade.G4);
              this.GradeOption(PracticeGrade.G5);
              this.GradeOption(PracticeGrade.G6);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('科目')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.SubjectOption(PracticeSubject.CHINESE);
              this.SubjectOption(PracticeSubject.MATH);
              this.SubjectOption(PracticeSubject.ENGLISH);
            }
            .width('100%');
          }
          .width('100%');

          Column({ space: 10 }) {
            Text('题库类型')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Row({ space: 8 }) {
              this.TrackOption(PracticeTrackFilter.ALL);
              this.TrackOption(PracticeTrackFilter.TEXTBOOK_SYNC);
              this.TrackOption(PracticeTrackFilter.EXTRACURRICULAR);
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

      Button('确定', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .fontWeight(FontWeight.Medium)
        .onClick(() => this.confirm())
        .margin({ left: 20, right: 20, top: 12, bottom: 18 });
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .height('58%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
