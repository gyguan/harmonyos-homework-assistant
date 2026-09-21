import {
  AppRoute,
  AssignmentRouteParam,
  ParentExtraCreateRouteParam,
  ParentCaptureRouteParam,
  ParentSourceProfileRouteParam,
  ParentCaptureSpikeRouteParam,
  ParentImportBatchRouteParam,
  ParentImportConfirmationRouteParam,
  ParentImportInboxRouteParam,
  ParentImportRouteParam,
  PracticeAttemptRouteParam,
  PracticeHistoryRouteParam,
  PracticePaperRouteParam
} from '../app/navigation/AppRoutes';
import { HomeworkCaptureSessionService } from '../application/capture/HomeworkCaptureSessionService';
import { ResponsiveContext, WindowSizeClass } from '../common/responsive/WindowSizeClass';
import { DemoScenario, DemoScenarioHelper } from '../common/state/DemoScenario';
import { AppTheme } from '../common/theme/AppTheme';
import { CenteredTextBadge } from '../components/family/CenteredTextBadge';
import { StudentSwitcherDialog } from '../components/family/StudentSwitcherDialog';
import { BottomPrimaryNavItem, SidePrimaryNavItem } from '../components/navigation/PrimaryNavItem';
import { PageStateView } from '../components/state/PageStateView';
import { DefaultAssignmentRepository } from '../data/repository/DefaultAssignmentRepository';
import { DefaultFamilyContextRepository } from '../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../domain/port/FamilyContextRepository';
import { HomeworkConfirmationPage } from '../features/parent/confirmation/HomeworkConfirmationPage';
import { ParentDashboardPage } from '../features/parent/dashboard/ParentDashboardPage';
import { ParentExtraAssignmentPage } from '../features/parent/extra/ParentExtraAssignmentPage';
import { ParentVoiceAssignmentPage } from '../features/parent/voice/ParentVoiceAssignmentPage';
import { HomeworkImportRoutePage } from '../features/parent/import/HomeworkImportRoutePage';
import { HomeworkImportInboxPage } from '../features/parent/import/HomeworkImportInboxPage';
import { HomeworkImportBatchDetailPage } from '../features/parent/import/HomeworkImportBatchDetailPage';
import { HomeworkShareImportStatusPage } from '../features/parent/import/HomeworkShareImportStatusPage';
import { HomeworkCapturePage } from '../features/parent/import/HomeworkCapturePage';
import { HomeworkSourceProfilePage } from '../features/parent/import/HomeworkSourceProfilePage';
import { HomeworkCaptureSpikePage } from '../experimental/homeworkcapture/HomeworkCaptureSpikePage';
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
  @Prop role: AppRole = AppRole.STUDENT;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  @State private widthVp: number = 390;
  @State private heightVp: number = 844;
  @State private studentRoute: StudentRoute = StudentRoute.HOME;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;
  @State private demoScenario: DemoScenario = DemoScenario.NORMAL;
  @State private storeRevision: number = 0;
  @State private activeStudentId: string = '';
  @State private familyStudents: StudentProfile[] = [];
  @StorageLink('shareImportToken') private shareImportToken: string = '';
  onRegisterBackHandler: (handler: () => boolean) => void = (_handler: () => boolean) => {};

  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

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

  private openStudentSwitcher(): void {
    if (this.role !== AppRole.PARENT || this.familyStudents.length <= 1) return;
    if (HomeworkCaptureSessionService.instance.getActiveSession() !== null) return;
    if (this.sizeClass === WindowSizeClass.EXPANDED) this.wideStudentSwitcherController.open();
    else this.phoneStudentSwitcherController.open();
  }

  private selectStudent(studentId: string): void {
    if (this.role !== AppRole.PARENT || studentId.length === 0 || studentId === this.activeStudentId) return;
    if (HomeworkCaptureSessionService.instance.getActiveSession() !== null) return;
    if (!this.familyContext.setActiveStudent(studentId)) return;

    // A child switch is a family-context boundary. Drop any detail route that may still point to
    // the previous child, return to Parent Home, update visible identity immediately, then refresh.
    this.navPathStack.clear();
    this.studentRoute = StudentRoute.HOME;
    this.parentRoute = ParentRoute.DASHBOARD;
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

  private openPracticeHistory(): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_PRACTICE_HISTORY, new PracticeHistoryRouteParam());
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

  private finishPracticeResult(): void {
    this.navPathStack.clear();
    this.studentRoute = StudentRoute.PRACTICE;
  }

  private openParentReview(assignmentId: string): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_REVIEW, new AssignmentRouteParam(assignmentId));
  }

  private openParentImport(): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_IMPORT, new ParentImportRouteParam());
  }

  private finishShareImportReady(): void {
    this.parentRoute = ParentRoute.DASHBOARD;
    this.navPathStack.clear();
    this.openParentImportConfirmation();
    this.shareImportToken = '';
  }

  private finishShareImportEmpty(): void {
    this.parentRoute = ParentRoute.DASHBOARD;
    this.navPathStack.clear();
    this.openParentImportInbox();
    this.shareImportToken = '';
  }

  private cancelShareImport(): void {
    this.shareImportToken = '';
  }

  private openParentImportInbox(): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_IMPORT_INBOX, new ParentImportInboxRouteParam());
  }

  private openParentImportBatch(batchId: string): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_IMPORT_BATCH_DETAIL, new ParentImportBatchRouteParam(batchId));
  }

  private openParentCapture(): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_CAPTURE, new ParentCaptureRouteParam());
  }

  private openParentSourceProfile(startCaptureAfterSave: boolean = false): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_SOURCE_PROFILE, new ParentSourceProfileRouteParam(startCaptureAfterSave));
  }

  private finishSourceProfile(startCaptureAfterSave: boolean): void {
    if (this.navPathStack.size() > 0) this.navPathStack.pop();
    this.notifyUiChanged();
    if (startCaptureAfterSave) this.openParentCapture();
  }

  private openParentCaptureSpike(): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_CAPTURE_SPIKE, new ParentCaptureSpikeRouteParam());
  }

  private openParentImportConfirmation(): void {
    this.navPathStack.pushPathByName(
      AppRoute.PARENT_IMPORT_CONFIRMATION, new ParentImportConfirmationRouteParam());
  }

  private openParentExtraCreate(voice: boolean = false): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_EXTRA_CREATE, new ParentExtraCreateRouteParam(voice));
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
        onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
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
          onStarted: (attemptId: string) => this.openPracticeAttempt(attemptId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_ATTEMPT) {
      NavDestination() {
        PracticeAttemptPage({
          attemptId: (param as PracticeAttemptRouteParam).attemptId,
          onBack: () => this.navPathStack.pop(),
          onSubmitted: (attemptId: string) => this.openPracticeResult(attemptId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.STUDENT_PRACTICE_RESULT) {
      NavDestination() {
        PracticeResultPage({
          attemptId: (param as PracticeAttemptRouteParam).attemptId,
          onDone: () => this.finishPracticeResult(),
          onRepeatStarted: (attemptId: string) => this.openPracticeAttempt(attemptId)
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
          onOpenConfirmation: () => this.openParentImportConfirmation(),
          onOpenInbox: () => this.openParentImportInbox(),
          onOpenCapture: () => this.openParentCapture(),
          onOpenSourceProfile: (startCaptureAfterSave: boolean) =>
            this.openParentSourceProfile(startCaptureAfterSave),
          onOpenCaptureSpike: () => this.openParentCaptureSpike(),
          onStoreChanged: () => this.notifyUiChanged()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_INBOX) {
      NavDestination() {
        HomeworkImportInboxPage({
          onBack: () => this.navPathStack.pop(),
          onOpenBatch: (batchId: string) => this.openParentImportBatch(batchId)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_BATCH_DETAIL) {
      NavDestination() {
        HomeworkImportBatchDetailPage({
          batchId: (param as ParentImportBatchRouteParam).batchId,
          onBack: () => this.navPathStack.pop(),
          onOpenConfirmation: () => this.openParentImportConfirmation()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_CAPTURE) {
      NavDestination() {
        HomeworkCapturePage({
          onBack: () => this.navPathStack.pop(),
          onOpenInbox: () => this.openParentImportInbox(),
          onOpenConfirmation: () => this.openParentImportConfirmation(),
          onOpenSourceProfile: (startCaptureAfterSave: boolean) =>
            this.openParentSourceProfile(startCaptureAfterSave)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_SOURCE_PROFILE) {
      NavDestination() {
        HomeworkSourceProfilePage({
          onBack: () => this.navPathStack.pop(),
          onSavedAndCapture: () => this.finishSourceProfile(
            (param as ParentSourceProfileRouteParam).startCaptureAfterSave)
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_CAPTURE_SPIKE) {
      NavDestination() {
        HomeworkCaptureSpikePage({
          onBack: () => this.navPathStack.pop()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_IMPORT_CONFIRMATION) {
      NavDestination() {
        HomeworkConfirmationPage({
          revision: this.storeRevision,
          onBack: () => this.navPathStack.pop(),
          onPublished: () => {
            this.parentRoute = ParentRoute.DASHBOARD;
            this.navPathStack.clear();
          },
          onStoreChanged: () => this.notifyUiChanged()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_EXTRA_CREATE) {
      NavDestination() {
        if ((param as ParentExtraCreateRouteParam).voice) {
          ParentVoiceAssignmentPage({
            onBack: () => this.navPathStack.pop(),
            onCreated: () => this.navPathStack.pop()
          });
        } else {
          ParentExtraAssignmentPage({
            onBack: () => this.navPathStack.pop(),
            onCreated: () => this.navPathStack.pop()
          });
        }
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
        revision: this.storeRevision,
        activeStudentId: this.activeStudentId,
        onOpenImport: () => this.openParentImport(),
        onOpenExtra: () => this.openParentExtraCreate(false),
        onOpenVoice: () => this.openParentExtraCreate(true),
        onOpenProgress: () => this.parentRoute = ParentRoute.PROGRESS,
        onOpenReview: (assignmentId: string) => this.openParentReview(assignmentId)
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
  private FamilyContextBar() {
    Row({ space: 10 }) {
      Column({ space: 1 }) {
        Text(this.currentStudent().name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.currentStudent().className)
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      if (this.familyStudents.length > 1) {
        Row({ space: 4 }) {
          Text('切换孩子').fontSize(12).fontColor(AppTheme.PRIMARY);
          Text('⌄').fontSize(12).fontColor(AppTheme.PRIMARY);
        }
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS)
        .accessibilityGroup(true)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`当前孩子 ${this.currentStudent().name}，点击选择孩子`)
        .onClick(() => this.openStudentSwitcher());
      }
    }
    .width('100%')
    .height(AppTheme.CONTEXT_BAR_HEIGHT)
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
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

      if (this.role === AppRole.PARENT) {
        Column({ space: 2 }) {
          Text(this.currentStudent().name)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          Text(this.currentStudent().className)
            .fontSize(10)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width(68)
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ top: 8, bottom: 8 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS)
        .accessibilityGroup(true)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`当前孩子 ${this.currentStudent().name}，点击选择孩子`)
        .onClick(() => this.openStudentSwitcher());
      } else {
        Text(this.currentStudent().name)
          .width(68)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.TEXT)
          .padding({ top: 8, bottom: 8 });
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
      if (this.role === AppRole.PARENT) {
        this.FamilyContextBar();
      }
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
