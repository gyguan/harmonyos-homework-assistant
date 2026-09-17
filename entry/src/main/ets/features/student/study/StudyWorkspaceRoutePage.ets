import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentStatus, AssignmentType } from '../../../domain/model/HomeworkModels';
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

  private assignment(): Assignment | null {
    let currentRevision = this.revision + this.activationRevision;
    if (currentRevision < 0) return null;
    return this.viewModel.assignment(this.assignmentId);
  }

  private isExtraAssignment(): boolean {
    let assignment = this.assignment();
    return assignment !== null && assignment.assignmentType === AssignmentType.EXTRA;
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

  @Builder
  private ExtraAssignmentContext() {
    if (this.isExtraAssignment() && this.assignment() !== null) {
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
          Text('与课内作业共用计时、AI 辅导、提交和同步链路，不建立第二套任务流程。')
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor(AppTheme.SUBTEXT);
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
      if (this.activationMessage.length > 0) {
        Text(this.activationMessage)
          .width('100%')
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .fontSize(12)
          .fontColor(AppTheme.WARNING)
          .backgroundColor(AppTheme.WARNING_SOFT);
      }
      this.ExtraAssignmentContext();
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
