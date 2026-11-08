import { VoiceMaterialAutoCreateService } from '../application/assignment/VoiceMaterialAutoCreateService';
import { BackendAuthService, SessionState } from '../application/remote/BackendAuthService';
import { BackendSession } from '../application/remote/BackendSession';
import { FamilyCloudService } from '../application/remote/FamilyCloudService';
import { ParentAccessRemoteApi } from '../application/remote/ParentAccessRemoteApi';
import { DefaultAssignmentRepository } from '../data/repository/DefaultAssignmentRepository';
import { ParentAccessDialog } from '../components/family/ParentAccessDialog';
import { CloudConnectionReminder } from '../components/family/CloudConnectionReminder';
import { BackendConnectionPage } from '../features/parent/settings/BackendConnectionPage';
import { DefaultFamilyContextRepository } from '../data/repository/DefaultFamilyContextRepository';
import { ParentIdentity } from '../domain/model/ParentIdentity';
import { FamilyContextRepository } from '../domain/port/FamilyContextRepository';
import { ParentAccessState } from '../domain/service/ParentAccessState';
import { AppRole, AppShell } from './AppShell';
import { PersonEntryPage } from './PersonEntryPage';

@Entry
@Component
struct Index {
  @State private selectedRole: AppRole = AppRole.NONE;
  @State private selectedParentIdentity: ParentIdentity = ParentIdentity.DAD;
  @State private pendingParentIdentity: ParentIdentity = ParentIdentity.DAD;
  @StorageLink('shareImportForceParent') @Watch('onShareImportForceParentChanged')
  private shareImportForceParent: boolean = false;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  @State private cloudRevision: number = 0;
  @State private showCloudConnectionReminder: boolean = false;
  @State private showCloudConnectionPage: boolean = false;
  @State private cloudSessionInvalid: boolean = false;
  // Student identity changes are independent of the role: STUDENT -> STUDENT
  // must invalidate the existing shell just as PARENT -> STUDENT does.
  @State private studentContextRevision: number = 0;
  @State private selectedStudentId: string = '';
  @State private parentAccessCodeInput: string = '';
  @State private parentAccessMessage: string = '';
  private shellBackHandler: () => boolean = () => false;
  private autoLoginInFlight: boolean = false;
  /** 401 重登失败后的退避截止时间戳，避免每 30s 轮询都拿旧口令重试把账号锁死。 */
  private autoLoginRetryAfterEpochMs: number = 0;

  private parentAccessController: CustomDialogController = new CustomDialogController({
    builder: ParentAccessDialog({
      code: $parentAccessCodeInput,
      message: $parentAccessMessage,
      onConfirm: () => { void this.confirmParentAccess(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    this.selectedStudentId = this.familyContext.getActiveStudentId();
    let shareImportActive = this.shareImportForceParent;
    if (BackendSession.instance.isConnected()) {
      void this.restoreCloud();
    } else if (!shareImportActive) {
      // 默认登录：先用内置家长账号静默连一次，成功就不再让家长手动输账号密码
      void this.autoLogin();
    }
    this.applyShareImportParentRole();
  }

  private async autoLogin(): Promise<void> {
    if (this.autoLoginInFlight) return;
    this.autoLoginInFlight = true;
    try {
      await BackendAuthService.instance.loginWithDefaults(BackendSession.instance.getBaseUrl());
      await this.restoreCloud();
    } catch {
      // 离线或服务器未启动时不阻塞本地使用，只保留连接提醒
      this.showCloudConnectionReminder = true;
    } finally {
      this.autoLoginInFlight = false;
    }
  }

  private openCloudConnectionPage(): void {
    this.showCloudConnectionReminder = false;
    this.showCloudConnectionPage = true;
  }

  private closeCloudConnectionPage(): void {
    this.showCloudConnectionPage = false;
  }

  private onCloudConnectionResolved(): void {
    this.cloudSessionInvalid = false;
  }

  private onCloudStoreChanged(): void {
    this.selectedStudentId = this.familyContext.getActiveStudentId();
    this.cloudRevision++;
    this.studentContextRevision++;
  }

  private onShareImportForceParentChanged(): void {
    this.applyShareImportParentRole();
  }

  private applyShareImportParentRole(): void {
    if (!this.shareImportForceParent) return;
    this.shareImportForceParent = false;
    void this.requestParentAccess(this.selectedParentIdentity);
  }

  onBackPress(): boolean {
    if (this.showCloudConnectionPage) {
      this.closeCloudConnectionPage();
      return true;
    }
    if (this.selectedRole === AppRole.NONE) return false;
    return this.shellBackHandler();
  }

  private async restoreCloud(): Promise<void> {
    let state = await BackendAuthService.instance.sessionState();
    if (state === SessionState.UNAUTHORIZED) {
      // 令牌过期：用默认账号静默重登一次，不要求家长重新输密码
      let now = Date.now();
      if (now < this.autoLoginRetryAfterEpochMs) {
        // 退避窗口内只提示，不再打登录接口（服务端有失败次数限流）。
        this.cloudSessionInvalid = true;
        this.showCloudConnectionReminder = true;
        return;
      }
      try {
        await BackendAuthService.instance.loginWithDefaults(BackendSession.instance.getBaseUrl());
        this.autoLoginRetryAfterEpochMs = 0;
        state = SessionState.OK;
      } catch {
        // 服务端改过默认口令时，旧口令会一直 401；5 分钟内只允许重试一次。
        this.autoLoginRetryAfterEpochMs = now + 5 * 60 * 1000;
        this.cloudSessionInvalid = true;
        this.showCloudConnectionReminder = true;
        return;
      }
    }
    if (state === SessionState.INVALID_RESPONSE) {
      // 200 但内容不是服务端的会话数据：保留离线可用的本地登录态，同时明确提示核对地址。
      this.cloudSessionInvalid = true;
      this.showCloudConnectionReminder = true;
      return;
    }
    if (state === SessionState.UNREACHABLE) {
      // 网络不可达时保留本地登录态，离线继续可用，不弹「请重新连接」
      return;
    }
    this.cloudSessionInvalid = false;
    let studentsSynced = await FamilyCloudService.instance.syncStudents();
    let parentAccessSynced = await FamilyCloudService.instance.syncParentAccess();
    if (studentsSynced) {
      this.selectedStudentId = this.familyContext.getActiveStudentId();
      this.cloudRevision++;
      this.studentContextRevision++;
    }
    if (!parentAccessSynced) {
      console.warn('Family parent access state synchronization failed');
    }
  }

  private async requestParentAccess(identity: ParentIdentity): Promise<void> {
    this.pendingParentIdentity = identity;

    if (BackendSession.instance.isConnected()) {
      let synced = await FamilyCloudService.instance.syncParentAccess();
      if (!synced) {
        this.parentAccessCodeInput = '';
        this.parentAccessMessage = '家长保护状态同步失败，请检查网络后重试';
        this.parentAccessController.open();
        return;
      }
    }

    let configuredState = this.familyContext.getSettings().parentAccessCode;
    if (!ParentAccessState.isEnabled(configuredState)) {
      this.enterParent(identity);
      return;
    }
    this.parentAccessCodeInput = '';
    this.parentAccessMessage = '';
    this.parentAccessController.open();
  }

  private async confirmParentAccess(): Promise<void> {
    let input = this.parentAccessCodeInput.trim();
    if (!ParentAccessState.isLegacyCode(input)) {
      this.parentAccessMessage = '请输入 4 位数字家长码';
      return;
    }

    if (BackendSession.instance.isConnected()) {
      try {
        let valid = await ParentAccessRemoteApi.instance.verify(input);
        if (!valid) {
          this.parentAccessMessage = '家长码不正确';
          return;
        }
      } catch {
        this.parentAccessMessage = '家长码验证失败，请检查网络后重试';
        return;
      }
    } else {
      let localValue = this.familyContext.getSettings().parentAccessCode;
      if (!ParentAccessState.isLegacyCode(localValue) || input !== localValue) {
        this.parentAccessMessage = localValue === ParentAccessState.CLOUD_ENABLED ?
          '当前无法连接家庭云端，暂时不能验证家长码' : '家长码不正确';
        return;
      }
    }

    this.parentAccessController.close();
    this.parentAccessCodeInput = '';
    this.parentAccessMessage = '';
    this.enterParent(this.pendingParentIdentity);
  }

  private enterParent(identity: ParentIdentity): void {
    this.selectedParentIdentity = identity;
    this.selectedRole = AppRole.PARENT;
    DefaultAssignmentRepository.instance.requestSync();
  }

  private enterStudent(studentId: string): void {
    if (this.familyContext.setActiveStudent(studentId)) {
      this.selectedStudentId = studentId;
      this.studentContextRevision++;
      this.selectedRole = AppRole.STUDENT;
      void this.prepareStudentAssignments(studentId);
    }
  }

  private async prepareStudentAssignments(studentId: string): Promise<void> {
    try {
      await VoiceMaterialAutoCreateService.instance.checkToday(studentId);
    } catch {
      console.warn('Student voice task initialization failed; refreshing assignments anyway');
    } finally {
      // Even if auto-create fails, the selected student's task list must sync.
      DefaultAssignmentRepository.instance.requestSync();
    }
  }

  build() {
    Stack() {
      if (this.showCloudConnectionPage) {
        BackendConnectionPage({
          embeddedInDeepPage: true,
          forceLogin: this.cloudSessionInvalid,
          onBack: () => this.closeCloudConnectionPage(),
          onStoreChanged: () => this.onCloudStoreChanged(),
          onConnectionResolved: () => this.onCloudConnectionResolved()
        });
      } else if (this.selectedRole === AppRole.NONE) {
        PersonEntryPage({
          revision: this.cloudRevision,
          onSelectParent: (identity: ParentIdentity) => { void this.requestParentAccess(identity); },
          onSelectStudent: (studentId: string) => this.enterStudent(studentId)
        });
      } else {
        AppShell({
          role: this.selectedRole,
          parentIdentity: this.selectedParentIdentity,
          studentContextRevision: this.studentContextRevision,
          rootStudentId: this.selectedStudentId,
          onSwitchParent: (identity: ParentIdentity) => { void this.requestParentAccess(identity); },
          onSwitchStudent: (studentId: string) => this.enterStudent(studentId),
          onRegisterBackHandler: (handler: () => boolean) => this.shellBackHandler = handler
        });
      }
      if (this.showCloudConnectionReminder && !this.showCloudConnectionPage) {
        CloudConnectionReminder({
          onConnect: () => this.openCloudConnectionPage(),
          onDismiss: () => this.showCloudConnectionReminder = false
        })
          .width('100%')
          .height('100%');
      }
    }.width('100%').height('100%');
  }
}
