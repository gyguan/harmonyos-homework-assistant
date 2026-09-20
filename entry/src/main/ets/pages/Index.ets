import { BackendAuthService } from '../application/remote/BackendAuthService';
import { BackendSession } from '../application/remote/BackendSession';
import { FamilyCloudService } from '../application/remote/FamilyCloudService';
import { DefaultAssignmentRepository } from '../data/repository/DefaultAssignmentRepository';
import { DefaultFamilyContextRepository } from '../data/repository/DefaultFamilyContextRepository';
import { FamilyContextRepository } from '../domain/port/FamilyContextRepository';
import { AppRole, AppShell } from './AppShell';
import { PersonEntryPage } from './PersonEntryPage';

@Entry
@Component
struct Index {
  @State private selectedRole: AppRole = AppRole.NONE;
  @StorageLink('shareImportForceParent') private shareImportForceParent: boolean = false;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
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
    DefaultAssignmentRepository.instance.requestSync();
  }

  private enterStudent(studentId: string): void {
    if (this.familyContext.setActiveStudent(studentId)) {
      this.selectedRole = AppRole.STUDENT;
      DefaultAssignmentRepository.instance.requestSync();
    }
  }

  build() {
    Stack() {
      if (this.selectedRole === AppRole.NONE && !this.shareImportForceParent) {
        PersonEntryPage({
          revision: this.cloudRevision,
          onSelectParent: () => this.enterParent(),
          onSelectStudent: (studentId: string) => this.enterStudent(studentId)
        });
      } else {
        AppShell({
          role: this.shareImportForceParent ? AppRole.PARENT : this.selectedRole,
          onRegisterBackHandler: (handler: () => boolean) => this.shellBackHandler = handler
        });
      }
    }.width('100%').height('100%');
  }
}
