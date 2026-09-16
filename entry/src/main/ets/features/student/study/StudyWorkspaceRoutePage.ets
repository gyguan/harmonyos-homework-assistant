import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { StudyWorkspacePage } from './StudyWorkspacePage';
import { StudyWorkspaceViewModel } from './StudyWorkspaceViewModel';

@Component
export struct StudyWorkspaceRoutePage {
  @Prop tutorUnavailable: boolean = false;
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  @State private activationRevision: number = 0;
  @State private activationMessage: string = '';
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: StudyWorkspaceViewModel =
    new StudyWorkspaceViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    void this.activateAssignment();
  }

  private shouldActivate(assignment: Assignment): boolean {
    return assignment.status === AssignmentStatus.NOT_STARTED ||
      assignment.status === AssignmentStatus.PAUSED ||
      assignment.status === AssignmentStatus.NEEDS_REWORK ||
      assignment.status === AssignmentStatus.OVERDUE;
  }

  private async activateAssignment(): Promise<void> {
    let assignment = this.viewModel.assignment(this.assignmentId);
    if (assignment === null || !this.shouldActivate(assignment)) return;
    try {
      await this.viewModel.performAction(this.assignmentId, AssignmentAction.START);
      this.activationRevision++;
      this.onStoreChanged();
    } catch {
      this.activationMessage = '暂时无法开始计时，可在学习页重试';
    }
  }

  build() {
    Column({ space: 0 }) {
      if (this.activationMessage.length > 0) {
        Text(this.activationMessage)
          .width('100%')
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .fontSize(12)
          .fontColor(AppTheme.WARNING)
          .backgroundColor(AppTheme.WARNING_SOFT);
      }
      Column() {
        StudyWorkspacePage({
          tutorUnavailable: this.tutorUnavailable,
          assignmentId: this.assignmentId,
          revision: this.revision + this.activationRevision,
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
