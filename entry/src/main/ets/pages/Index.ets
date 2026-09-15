import { BackendAuthService } from '../application/remote/BackendAuthService';
import { BackendSession } from '../application/remote/BackendSession';
import { FamilyCloudService } from '../application/remote/FamilyCloudService';
import { HomeworkSyncService } from '../application/remote/HomeworkSyncService';
import { HomeworkStore } from '../data/HomeworkStore';
import { AppRole, AppShell } from './AppShell';
import { PersonEntryPage } from './PersonEntryPage';

@Entry
@Component
struct Index {
  @State private selectedRole: AppRole = AppRole.NONE;
  @State private cloudRevision: number = 0;
  private shellBackHandler: () => boolean = () => false;

  aboutToAppear(): void {
    if (BackendSession.instance.isConnected()) void this.restoreCloud();
  }

  onBackPress(): boolean {
    if (this.selectedRole === AppRole.NONE) return false;
    return this.shellBackHandler();
  }

  private async restoreCloud(): Promise<void> {
    let valid = await BackendAuthService.instance.validateSession();
    if (!valid) return;
    if (await FamilyCloudService.instance.syncStudents()) this.cloudRevision++;
  }

  private enterParent(): void {
    this.selectedRole = AppRole.PARENT;
    HomeworkSyncService.instance.requestSync();
  }

  private enterStudent(studentId: string): void {
    if (HomeworkStore.instance.setActiveStudent(studentId)) {
      this.selectedRole = AppRole.STUDENT;
      HomeworkSyncService.instance.requestSync();
    }
  }

  build() {
    Stack() {
      if (this.selectedRole === AppRole.NONE) {
        PersonEntryPage({
          revision: this.cloudRevision,
          onSelectParent: () => this.enterParent(),
          onSelectStudent: (studentId: string) => this.enterStudent(studentId)
        });
      } else {
        AppShell({
          role: this.selectedRole,
          onRegisterBackHandler: (handler: () => boolean) => this.shellBackHandler = handler
        });
      }
    }.width('100%').height('100%');
  }
}
