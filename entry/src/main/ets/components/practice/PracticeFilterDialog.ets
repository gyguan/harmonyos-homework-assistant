import { AppTheme } from '../../common/theme/AppTheme';
import { ActionButton, TextAction, TextActionKind } from '../action/ActionControls';
import { SegmentedSelectionButton } from '../selection/SelectionControls';
import {
  PracticeGrade,
  PracticePassFilter,
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
  @Link selectedPassFilter: PracticePassFilter;
  onApply: (grade: PracticeGrade, subject: PracticeSubject, track: PracticeTrackFilter,
    passFilter: PracticePassFilter) => void =
    (_grade: PracticeGrade, _subject: PracticeSubject, _track: PracticeTrackFilter,
      _passFilter: PracticePassFilter) => {};

  @Builder
  private GradeOption(grade: PracticeGrade) {
    SegmentedSelectionButton({
      label: PracticeTaxonomy.gradeLabel(grade),
      selected: this.selectedGrade === grade,
      onSelect: () => this.selectedGrade = grade
    })
    .layoutWeight(1);
  }

  @Builder
  private TrackOption(track: PracticeTrackFilter) {
    SegmentedSelectionButton({
      label: PracticeTaxonomy.trackFilterLabel(track),
      selected: this.selectedTrack === track,
      onSelect: () => this.selectedTrack = track
    })
    .layoutWeight(1);
  }

  private confirm(): void {
    this.onApply(this.selectedGrade, this.selectedSubject, this.selectedTrack, this.selectedPassFilter);
  }

  build() {
    Column() {
      Row() {
        Text('更多筛选')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        TextAction({
          label: '关闭',
          kind: TextActionKind.NEUTRAL,
          accessibilityLabel: '关闭更多筛选',
          onClick: () => this.controller.close()
        });
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

      ActionButton({
        label: '确定',
        onClick: () => this.confirm()
      })
      .width('100%')
      .margin({ left: 20, right: 20, top: 12, bottom: 18 });
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.FILTER_DIALOG_MAX_WIDTH })
    .height('48%')
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
