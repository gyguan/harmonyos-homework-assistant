import {
  AppRoute,
  AssignmentRouteParam,
  ParentVoiceCreateRouteParam,
  PracticeAttemptRouteParam,
  PracticeHistoryRouteParam,
  PracticePaperRouteParam
} from '../app/navigation/AppRoutes';
import { ParentImportNavigator } from '../app/navigation/ParentImportNavigator';
import { ResponsiveContext, WindowSizeClass } from '../common/responsive/WindowSizeClass';
import { DemoScenario, DemoScenarioHelper } from '../common/state/DemoScenario';
import { AppTheme } from '../common/theme/AppTheme';
import { CenteredTextBadge } from '../components/family/CenteredTextBadge';
import { IdentityContextBar } from '../components/family/IdentityContextBar';
import { IdentitySwitcherDialog } from '../components/family/IdentitySwitcherDialog';
import { StudentSwitcherDialog } from '../components/family/StudentSwitcherDialog';
import { BottomPrimaryNavItem, SidePrimaryNavItem } from '../components/navigation/PrimaryNavItem';
import { PageStateView } from '../components/state/PageStateView';
import { DefaultAssignmentRepository } from '../data/repository/DefaultAssignmentRepository';
import { DefaultFamilyContextRepository } from '../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../domain/port/FamilyContextRepository';
import { HomeworkConfirmationPage } from '../features/parent/confirmation/HomeworkConfirmationPage';
import { ParentDashboardPage } from '../features/parent/dashboard/ParentDashboardPage';
import { ParentVoiceAssignmentPage } from '../features/parent/voice/ParentVoiceAssignmentPage';
import { HomeworkImportRoutePage } from '../features/parent/import/HomeworkImportRoutePage';
import { HomeworkImportInboxPage } from '../features/parent/import/HomeworkImportInboxPage';
import { HomeworkImportBatchDetailPage } from '../features/parent/import/HomeworkImportBatchDetailPage';
import { HomeworkShareImportStatusPage } from '../features/parent/import/HomeworkShareImportStatusPage';
import { ParentProgressPage } from '../features/parent/progress/ParentProgressPage';
import { ParentReviewPage } from '../features/parent/review/ParentReviewPage';
import { BackendConnectionPage } from '../features/parent/settings/BackendConnectionPage';
import { StudentAssignmentDetailPage } from '../features/student/assignments/StudentAssignmentDetailPage';
import { StudentAssignmentsPage } from '../features/student/assignments/StudentAssignmentsPage';
import { StudentHomePage } from '../features/student/home/StudentHomePage';
import { StudentProfilePage } from '../features/student/profile/StudentProfilePage';
import { PracticeHomePage } from '../features/student/practice/PracticeHomePage';
import { PracticeHistoryPage } from '../features/student/practice/PracticeHistoryPage';
import { PracticeAttemptPage } from '../features/student/practice/PracticeAttemptPage';
import { PracticePaperDetailPage } from '../features/student/practice/PracticePaperDetailPage';
import { PracticeResultPage } from '../features/student/practice/PracticeResultPage';
import { StudyWorkspaceRoutePage } from '../features/student/study/StudyWorkspaceRoutePage';

export enum AppRole {
  NONE = 'NONE',
  STUDENT = 'STUDENT',
  PARENT = 'PARENT'
}

enum StudentRoute {
  HOME = 'HOME',
  ASSIGNMENTS = 'ASSIGNMENTS',
  PRACTICE = 'PRACTICE',
  PROFILE = 'PROFILE'
}

enum ParentRoute {
  DASHBOARD = 'DASHBOARD',
  PROGRESS = 'PROGRESS',
  SETTINGS = 'SETTINGS'
}

@Component
export struct AppShell {
  @Prop @Watch('onRoleChanged') role: AppRole = AppRole.STUDENT;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  @State private widthVp: number = 390;
  @State private heightVp: number = 844;
  @State private studentRoute: StudentRoute = StudentRoute.HOME;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;
  @State private demoScenario: DemoScenario = DemoScenario.NORMAL;
  @State private storeRevision: number = 0;
  @State private activeStudentId: string = '';
  @State private familyStudents: StudentProfile[] = [];
  @State private identityParentActive: boolean = false;
  @StorageLink('shareImportToken') private shareImportToken: string = '';
  onSwitchParent: () => void = () => {};
  onSwitchStudent: (studentId: string) => void = (_studentId: string) => {};
  onRegisterBackHandler: (handler: () => boolean) => void = (_handler: () => boolean) => {};

  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

  private phoneIdentitySwitcherController: CustomDialogController = new CustomDialogController({
    builder: IdentitySwitcherDialog({
      students: $familyStudents,
      activeStudentId: $activeStudentId,
      parentActive: $identityParentActive,
      onSelectParent: () => this.switchToParent(),
      onSelectStudent: (studentId: string) => this.switchToStudent(studentId)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private wideIdentitySwitcherController: CustomDialogController = new CustomDialogController({
    builder: IdentitySwitcherDialog({
      students: $familyStudents,
      activeStudentId: $activeStudentId,
      parentActive: $identityParentActive,
      onSelectParent: () => this.switchToParent(),
      onSelectStudent: (studentId: string) => this.switchToStudent(studentId)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private phoneStudentSwitcherController: CustomDialogController = new CustomDialogController({
    builder: StudentSwitcherDialog({
      students: $familyStudents,
      activeStudentId: $activeStudentId,
      onSelect: (studentId: string) => this.selectStudent(studentId)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private wideStudentSwitcherController: CustomDialogController = new CustomDialogController({
    builder: StudentSwitcherDialog({
      students: $familyStudents,
      activeStudentId: $activeStudentId,
      onSelect: (studentId: string) => this.selectStudent(studentId)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    DefaultAssignmentRepository.instance.setChangeListener(() => this.notifyUiChanged());
    this.syncFamilyContext();
    this.onRegisterBackHandler(() => this.handleSystemBack());
    void this.refreshActiveStudent();
  }

  aboutToDisappear(): void {
    DefaultAssignmentRepository.instance.clearChangeListener();
    this.onRegisterBackHandler(() => false);
  }

  private get sizeClass(): WindowSizeClass {
    return ResponsiveContext.resolve(this.widthVp);
  }

  private handleSystemBack(): boolean {
    if (this.navPathStack.size() > 0) {
      this.navPathStack.pop();
      return true;
    }
    return false;
  }

  private nextDemoScenario(): void {
    this.demoScenario = DemoScenarioHelper.next(this.demoScenario);
  }

  private syncFamilyContext(): void {
    this.familyStudents = this.familyContext.getStudents();
    this.activeStudentId = this.familyContext.getActiveStudentId();
  }

  private currentStudent(): StudentProfile {
    for (let student of this.familyStudents) {
      if (student.id === this.activeStudentId) return student;
    }
    return this.familyContext.getStudent();
  }

  private notifyUiChanged(): void {
    // Child commands already apply the authoritative server response to repositories.
    // UI invalidation must not implicitly trigger another full assignment synchronization.
    this.syncFamilyContext();
    this.storeRevision++;
  }

  private resetPersonaNavigation(): void {
    this.navPathStack.clear();
    this.studentRoute = StudentRoute.HOME;
    this.parentRoute = ParentRoute.DASHBOARD;
  }

  private onRoleChanged(): void {
    this.resetPersonaNavigation();
    this.identityParentActive = this.role === AppRole.PARENT;
    this.syncFamilyContext();
    this.storeRevision++;
  }

  private openIdentitySwitcher(): void {
    this.identityParentActive = this.role === AppRole.PARENT;
    if (this.sizeClass === WindowSizeClass.EXPANDED) this.wideIdentitySwitcherController.open();
    else this.phoneIdentitySwitcherController.open();
  }

  private switchToParent(): void {
    if (this.role === AppRole.PARENT) return;
    this.onSwitchParent();
  }

  private switchToStudent(studentId: string): void {
    if (studentId.length === 0 ||
      (this.role === AppRole.STUDENT && studentId === this.activeStudentId)) return;
    if (this.role === AppRole.STUDENT) this.resetPersonaNavigation();
    this.onSwitchStudent(studentId);
  }

  private openStudentSwitcher(): void {
    if (this.role !== AppRole.PARENT || this.familyStudents.length <= 1) return;
    if (this.sizeClass === WindowSizeClass.EXPANDED) this.wideStudentSwitcherController.open();
    else this.phoneStudentSwitcherController.open();
  }

  private selectStudent(studentId: string): void {
    if (this.role !== AppRole.PARENT || studentId.length === 0 || studentId === this.activeStudentId) return;
    if (!this.familyContext.setActiveStudent(studentId)) return;

    // A child switch is a family-context boundary. Drop any detail route that may still point to
    // the previous child, return to Parent Home, update visible identity immediately, then refresh.
    this.resetPersonaNavigation();
    this.syncFamilyContext();
    this.storeRevision++;
    void this.refreshActiveStudent();
  }

  private async refreshActiveStudent(): Promise<void> {
    await DefaultAssignmentRepository.instance.refresh();
    this.syncFamilyContext();
  }

  private openAssignmentDetail(assignmentId: string): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_ASSIGNMENT_DETAIL, new AssignmentRouteParam(assignmentId));
  }

  private openStudy(assignmentId: string): void {
    this.navPathStack.pushPathByName(AppRoute.STUDENT_STUDY, new AssignmentRouteParam(assignmentId));
  }

  private openPracticeHistory(paperId: string = ''): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_PRACTICE_HISTORY, new PracticeHistoryRouteParam(paperId));
  }

  private openPracticePaper(paperId: string, version: number): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_PRACTICE_PAPER, new PracticePaperRouteParam(paperId, version));
  }

  private openPracticeAttempt(attemptId: string): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_PRACTICE_ATTEMPT, new PracticeAttemptRouteParam(attemptId));
  }

  private openPracticeResult(attemptId: string): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_PRACTICE_RESULT, new PracticeAttemptRouteParam(attemptId));
  }

  private replacePracticeAttemptWithResult(attemptId: string): void {
    this.navPathStack.pop();
    this.openPracticeResult(attemptId);
  }

  private replacePracticeResultWithAttempt(attemptId: string): void {
    this.navPathStack.pop();
    this.openPracticeAttempt(attemptId);
  }

  private openParentReview(assignmentId: string): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_REVIEW, new AssignmentRouteParam(assignmentId));
  }

  private finishShareImportReady(): void {
    this.shareImportToken = '';
    ParentImportNavigator.openConfirmation(this.navPathStack);
  }

  private finishShareImportEmpty(): void {
    this.shareImportToken = '';
    ParentImportNavigator.openInbox(this.navPathStack);
  }

  private cancelShareImport(): void {
    this.shareImportToken = '';
  }

  private finishParentImportPublished(): void {
    this.parentRoute = ParentRoute.DASHBOARD;
    this.navPathStack.clear();
    // Batch publish already updates the authoritative assignment cache.
    this.notifyUiChanged();
  }

  private openParentVoiceCreate(): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_VOICE_CREATE, new ParentVoiceCreateRouteParam());
  }

  private routeAssignmentId(param: Object): string {
    return (param as AssignmentRouteParam).assignmentId;
  }

  private isBlockingPageState(): boolean {
    return this.demoScenario === DemoScenario.LOADING ||
      this.demoScenario === DemoScenario.EMPTY ||
      this.demoScenario === DemoScenario.ERROR;
  }

  @Builder
  private StudentContent() {
    if (this.studentRoute === StudentRoute.ASSIGNMENTS) {
      StudentAssignmentsPage({
        revision: this.storeRevision,
        onOpenDetail: (assignmentId: string) => this.openAssignmentDetail(assignmentId),
        onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
      });
    } else if (this.studentRoute === StudentRoute.PRACTICE) {
      PracticeHomePage({
        revision: this.storeRevision,
        onOpenPaper: (paperId: string, version: number) => this.openPracticePaper(paperId, version),
        onOpenHistory: () => this.openPracticeHistory()
      });
    } else if (this.studentRoute === StudentRoute.PROFILE) {
      StudentProfilePage({
        revision: this.storeRevision
      });
    } else {
      StudentHomePage({
        offlineMode: this.demoScenario === DemoScenario.OFFLINE,
        revision: this.storeRevision,
        onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId),
        onStoreChanged: () => this.notifyUiChanged()
      });
    }
  }

  @Builder
  private AppNavDestination(name: string, param: Object) {
    if (name === AppRoute.STUDENT_ASSIGNMENT_DETAIL) {
      NavDestination() {
        StudentAssignmentDetailPage({
          assignmentId: this.routeAssignmentId(param),
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop(),
          onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_STUDY) {
      NavDestination() {
        StudyWorkspaceRoutePage({
          tutorUnavailable: this.demoScenario === DemoScenario.TUTOR_UNAVAILABLE,
          assignmentId: this.routeAssignmentId(param),
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_HISTORY) {
      NavDestination() {
        PracticeHistoryPage({
          paperId: (param as PracticeHistoryRouteParam).paperId,
          onBack: () => this.navPathStack.pop(),
          onOpenAttempt: (attemptId: string) => this.openPracticeAttempt(attemptId),
          onOpenResult: (attemptId: string) => this.openPracticeResult(attemptId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_PAPER) {
      NavDestination() {
        PracticePaperDetailPage({
          paperId: (param as PracticePaperRouteParam).paperId,
          version: (param as PracticePaperRouteParam).version,
          onBack: () => this.navPathStack.pop(),
          onStarted: (attemptId: string) => this.openPracticeAttempt(attemptId),
          onOpenAttempt: (attemptId: string) => this.openPracticeAttempt(attemptId),
          onOpenHistory: (paperId: string) => this.openPracticeHistory(paperId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_ATTEMPT) {
      NavDestination() {
        PracticeAttemptPage({
          attemptId: (param as PracticeAttemptRouteParam).attemptId,
          onBack: () => this.navPathStack.pop(),
          onSubmitted: (attemptId: string) => this.replacePracticeAttemptWithResult(attemptId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_RESULT) {
      NavDestination() {
        PracticeResultPage({
          attemptId: (param as PracticeAttemptRouteParam).attemptId,
          onBack: () => this.navPathStack.pop(),
          onRepeatStarted: (attemptId: string) => this.replacePracticeResultWithAttempt(attemptId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_REVIEW) {
      NavDestination() {
        ParentReviewPage({
          assignmentId: this.routeAssignmentId(param),
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop(),
          onReviewed: () => {},
          onDeleted: () => this.navPathStack.pop()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT) {
      NavDestination() {
        HomeworkImportRoutePage({
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop(),
          onOpenConfirmation: () => ParentImportNavigator.openConfirmation(this.navPathStack),
          onStoreChanged: () => this.notifyUiChanged()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_INBOX) {
      NavDestination() {
        HomeworkImportInboxPage({
          onBack: () => this.navPathStack.pop(),
          onOpenBatch: (batchId: string) => ParentImportNavigator.openBatch(
            this.navPathStack, batchId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_BATCH_DETAIL) {
      NavDestination() {
        HomeworkImportBatchDetailPage({
          batchId: ParentImportNavigator.batchId(param),
          onBack: () => this.navPathStack.pop(),
          onOpenConfirmation: () => ParentImportNavigator.openConfirmation(this.navPathStack)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_CONFIRMATION) {
      NavDestination() {
        HomeworkConfirmationPage({
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop(),
          onPublished: () => this.finishParentImportPublished(),
          onStoreChanged: () => this.notifyUiChanged()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_VOICE_CREATE) {
      NavDestination() {
        ParentVoiceAssignmentPage({
          onBack: () => this.navPathStack.pop(),
          onCreated: () => {
            this.navPathStack.pop();
            this.notifyUiChanged();
          }
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    }
  }

  @Builder
  private ParentContent() {
    if (this.parentRoute === ParentRoute.PROGRESS) {
      ParentProgressPage({
        revision: this.storeRevision,
        onOpenReview: (assignmentId: string) => this.openParentReview(assignmentId)
      });
    } else if (this.parentRoute === ParentRoute.SETTINGS) {
      BackendConnectionPage({
        onStoreChanged: () => this.notifyUiChanged()
      });
    } else {
      ParentDashboardPage({
        onOpenAssignment: () => ParentImportNavigator.openImport(this.navPathStack),
        onOpenInbox: () => ParentImportNavigator.openInbox(this.navPathStack),
        onOpenVoice: () => this.openParentVoiceCreate()
      });
    }
  }

  @Builder
  private PersonaContent() {
    if (this.isBlockingPageState()) {
      PageStateView({ scenario: this.demoScenario });
    } else if (this.role === AppRole.STUDENT) {
      this.StudentContent();
    } else {
      this.ParentContent();
    }
  }

  @Builder
  private BottomNavigation() {
    Row() {
      if (this.role === AppRole.STUDENT) {
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.house'), label: '首页', selected: this.studentRoute === StudentRoute.HOME,
          onSelect: () => this.studentRoute = StudentRoute.HOME
        }).layoutWeight(1).height('100%');
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_square'), label: '作业', selected: this.studentRoute === StudentRoute.ASSIGNMENTS,
          onSelect: () => this.studentRoute = StudentRoute.ASSIGNMENTS
        }).layoutWeight(1).height('100%');
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_circle'), label: '练习', selected: this.studentRoute === StudentRoute.PRACTICE,
          onSelect: () => this.studentRoute = StudentRoute.PRACTICE
        }).layoutWeight(1).height('100%');
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.gearshape'), label: '我的', selected: this.studentRoute === StudentRoute.PROFILE,
          onSelect: () => this.studentRoute = StudentRoute.PROFILE
        }).layoutWeight(1).height('100%');
      } else {
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.house'), label: '首页', selected: this.parentRoute === ParentRoute.DASHBOARD,
          onSelect: () => this.parentRoute = ParentRoute.DASHBOARD
        }).layoutWeight(1).height('100%');
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_circle'), label: '进度', selected: this.parentRoute === ParentRoute.PROGRESS,
          onSelect: () => this.parentRoute = ParentRoute.PROGRESS
        }).layoutWeight(1).height('100%');
        BottomPrimaryNavItem({
          symbol: $r('sys.symbol.gearshape'), label: '我的', selected: this.parentRoute === ParentRoute.SETTINGS,
          onSelect: () => this.parentRoute = ParentRoute.SETTINGS
        }).layoutWeight(1).height('100%');
      }
    }
    .width('100%')
    .height(AppTheme.BOTTOM_NAV_HEIGHT)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
  }

  @Builder
  private SideNavigation() {
    Column({ space: 8 }) {
      CenteredTextBadge({
        badgeText: '伴',
        badgeWidth: 46,
        badgeHeight: 46,
        badgeFontSize: 20,
        badgeRadius: 15,
        badgeBold: true,
        badgeForeground: AppTheme.TEXT_ON_PRIMARY,
        badgeBackground: AppTheme.PRIMARY
      })
        .margin({ bottom: 14 });

      if (this.role === AppRole.STUDENT) {
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.house'), label: '首页', selected: this.studentRoute === StudentRoute.HOME,
          onSelect: () => this.studentRoute = StudentRoute.HOME
        });
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_square'), label: '作业', selected: this.studentRoute === StudentRoute.ASSIGNMENTS,
          onSelect: () => this.studentRoute = StudentRoute.ASSIGNMENTS
        });
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_circle'), label: '练习', selected: this.studentRoute === StudentRoute.PRACTICE,
          onSelect: () => this.studentRoute = StudentRoute.PRACTICE
        });
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.gearshape'), label: '我的', selected: this.studentRoute === StudentRoute.PROFILE,
          onSelect: () => this.studentRoute = StudentRoute.PROFILE
        });
      } else {
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.house'), label: '首页', selected: this.parentRoute === ParentRoute.DASHBOARD,
          onSelect: () => this.parentRoute = ParentRoute.DASHBOARD
        });
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.checkmark_circle'), label: '进度', selected: this.parentRoute === ParentRoute.PROGRESS,
          onSelect: () => this.parentRoute = ParentRoute.PROGRESS
        });
        SidePrimaryNavItem({
          symbol: $r('sys.symbol.gearshape'), label: '我的', selected: this.parentRoute === ParentRoute.SETTINGS,
          onSelect: () => this.parentRoute = ParentRoute.SETTINGS
        });
      }

      Blank();

      Column({ space: 3 }) {
        CenteredTextBadge({
          badgeText: this.role === AppRole.PARENT ? '家' :
            (this.currentStudent().name.length > 0 ? this.currentStudent().name.substring(0, 1) : '伴'),
          badgeWidth: 34,
          badgeHeight: 34,
          badgeFontSize: 13,
          badgeRadius: 11,
          badgeBold: true,
          badgeForeground: AppTheme.PRIMARY,
          badgeBackground: AppTheme.PRIMARY_SOFT
        });
        Text(this.role === AppRole.PARENT ? '家长' : this.currentStudent().name)
          .width(68)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('切换')
          .fontSize(11)
          .fontColor(AppTheme.PRIMARY);
      }
      .width(68)
      .constraintSize({ minHeight: 76 })
      .padding({ top: 7, bottom: 7 })
      .backgroundColor(AppTheme.CARD_SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.role === AppRole.PARENT ?
        '当前身份家长，点击切换身份' : '当前身份 ' + this.currentStudent().name + '，点击切换身份')
      .onClick(() => this.openIdentitySwitcher());

      if (this.role === AppRole.PARENT && this.familyStudents.length > 1) {
        Text('管理 ' + this.currentStudent().name)
          .width(68)
          .fontSize(10)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ top: 8, bottom: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('当前管理 ' + this.currentStudent().name + '，点击切换孩子')
          .onClick(() => this.openStudentSwitcher());
      }
    }
    .width(AppTheme.SIDE_NAV_WIDTH)
    .height('100%')
    .padding({ top: 20, bottom: 18 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { right: 1 }, color: AppTheme.DIVIDER });
  }

  @Builder
  private BottomNavShell() {
    Column() {
      IdentityContextBar({
        isParent: this.role === AppRole.PARENT,
        studentName: this.currentStudent().name,
        studentGrade: this.currentStudent().grade,
        studentClassName: this.currentStudent().className,
        canSwitchStudent: this.familyStudents.length > 1,
        onSwitchIdentity: () => this.openIdentitySwitcher(),
        onSwitchStudent: () => this.openStudentSwitcher()
      });
      Column() {
        this.PersonaContent();
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);

      this.BottomNavigation();
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start);
  }

  @Builder
  private SideNavShell() {
    Row() {
      this.SideNavigation();
      Column() {
        this.PersonaContent();
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private ShellContent() {
    Stack() {
      if (this.shareImportToken.length > 0) {
        Column() {
          HomeworkShareImportStatusPage({
            token: this.shareImportToken,
            onReady: () => this.finishShareImportReady(),
            onOpenInbox: () => this.finishShareImportEmpty(),
            onCancel: () => this.cancelShareImport()
          });
        }
        .width('100%')
        .height('100%')
        .padding(AppTheme.PAGE_PADDING)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.sizeClass === WindowSizeClass.EXPANDED) {
        this.SideNavShell();
      } else {
        this.BottomNavShell();
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.widthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.widthVp);
      this.heightVp = ResponsiveContext.areaLengthToVp(newValue.height, this.heightVp);
    });
  }

  build() {
    Navigation(this.navPathStack) {
      this.ShellContent();
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.AppNavDestination)
    .width('100%')
    .height('100%');
  }
}
