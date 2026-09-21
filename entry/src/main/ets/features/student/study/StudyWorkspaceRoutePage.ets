import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentContentType, AssignmentType } from '../../../domain/model/HomeworkModels';
import { StudyWorkspacePage } from './StudyWorkspacePage';
import { StudyWorkspaceViewModel } from './StudyWorkspaceViewModel';

@Component
export struct StudyWorkspaceRoutePage {
  @Prop tutorUnavailable: boolean = false;
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: StudyWorkspaceViewModel =
    new StudyWorkspaceViewModel(DefaultAssignmentRepository.instance);

  private assignment(): Assignment | null {
    let currentRevision = this.revision;
    if (currentRevision < 0) return null;
    return this.viewModel.assignment(this.assignmentId);
  }

  private shouldShowExtraAssignmentContext(): boolean {
    let assignment = this.assignment();
    return assignment !== null &&
      assignment.assignmentType === AssignmentType.EXTRA &&
      assignment.contentType !== AssignmentContentType.AUDIO_IMAGE;
  }

  @Builder
  private ExtraAssignmentContext() {
    if (this.shouldShowExtraAssignmentContext() && this.assignment() !== null) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.star_fill'))
          .fontSize(18)
          .fontColor([AppTheme.PRIMARY]);
        Column({ space: 2 }) {
          Text(`课外任务 · ${this.assignment()!.subject}`)
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.PRIMARY_FAINT);
    }
  }

  build() {
    Column({ space: 0 }) {
      this.ExtraAssignmentContext();
      Column() {
        StudyWorkspacePage({
          tutorUnavailable: this.tutorUnavailable,
          assignmentId: this.assignmentId,
          revision: this.revision,
          onBack: () => this.onBack(),
          onStoreChanged: () => this.onStoreChanged()
        });
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
