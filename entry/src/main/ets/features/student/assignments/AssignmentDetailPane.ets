import { StudyWorkspacePage } from '../study/StudyWorkspacePage';

@Component
export struct AssignmentDetailPane {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onStoreChanged: () => void = () => {};

  build() {
    StudyWorkspacePage({
      assignmentId: this.assignmentId,
      revision: this.revision,
      onStoreChanged: () => this.onStoreChanged()
    });
  }
}
