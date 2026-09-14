import { HomeworkStore } from '../data/HomeworkStore';
import { AppRole, AppShell } from './AppShell';
import { PersonEntryPage } from './PersonEntryPage';

@Entry
@Component
struct Index {
  @State private selectedRole: AppRole = AppRole.NONE;

  private enterParent(): void {
    this.selectedRole = AppRole.PARENT;
  }

  private enterStudent(studentId: string): void {
    if (HomeworkStore.instance.setActiveStudent(studentId)) {
      this.selectedRole = AppRole.STUDENT;
    }
  }

  build() {
    Stack() {
      if (this.selectedRole === AppRole.NONE) {
        PersonEntryPage({
          onSelectParent: () => this.enterParent(),
          onSelectStudent: (studentId: string) => this.enterStudent(studentId)
        });
      } else {
        AppShell({ role: this.selectedRole });
      }
    }
    .width('100%')
    .height('100%');
  }
}
