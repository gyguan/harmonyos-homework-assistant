import { HomeworkSyncService } from '../application/remote/HomeworkSyncService';
import { AppRoute, AssignmentRouteParam, ParentExtraCreateRouteParam } from '../app/navigation/AppRoutes';
import { ResponsiveContext, WindowSizeClass } from '../common/responsive/WindowSizeClass';
import { DemoScenario, DemoScenarioHelper } from '../common/state/DemoScenario';
import { AppTheme } from '../common/theme/AppTheme';
import { PageStateView } from '../components/state/PageStateView';
import { HomeworkStore } from '../data/HomeworkStore';
import { StudentProfile } from '../domain/model/HomeworkModels';
import { HomeworkConfirmationPage } from '../features/parent/confirmation/HomeworkConfirmationPage';
import { ParentDashboardPage } from '../features/parent/dashboard/ParentDashboardPage';
import { ParentExtraAssignmentPage } from '../features/parent/extra/ParentExtraAssignmentPage';
import { HomeworkImportPage } from '../features/parent/import/HomeworkImportPage';
import { ParentProgressPage } from '../features/parent/progress/ParentProgressPage';
import { ParentReviewPage } from '../features/parent/review/ParentReviewPage';
import { BackendConnectionPage } from '../features/parent/settings/BackendConnectionPage';
import { StudentAssignmentDetailPage } from '../features/student/assignments/StudentAssignmentDetailPage';
import { StudentAssignmentsPage } from '../features/student/assignments/StudentAssignmentsPage';
import { StudentHomePage } from '../features/student/home/StudentHomePage';
import { StudentProfilePage } from '../features/student/profile/StudentProfilePage';
import { StudyWorkspaceRoutePage } from '../features/student/study/StudyWorkspaceRoutePage';

export enum AppRole {
  NONE = 'NONE',
  STUDENT = 'STUDENT',
  PARENT = 'PARENT'
}

enum StudentRoute {
  HOME = 'HOME',
  ASSIGNMENTS = 'ASSIGNMENTS',
  PROFILE = 'PROFILE'
}

enum ParentRoute {
  DASHBOARD = 'DASHBOARD',
  IMPORT = 'IMPORT',
  CONFIRMATION = 'CONFIRMATION',
  PROGRESS = 'PROGRESS',
  SETTINGS = 'SETTINGS'
}

@Component
export struct AppShell {
  @Prop role: AppRole = AppRole.STUDENT;
  @State private widthVp: number = 390;
  @State private heightVp: number = 844;
  @State private studentRoute: StudentRoute = StudentRoute.HOME;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;
  @State private demoScenario: DemoScenario = DemoScenario.NORMAL;
  @State private storeRevision: number = 0;
  onRegisterBackHandler: (handler: () => boolean) => void = (_handler: () => boolean) => {};

  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.onRegisterBackHandler(() => this.handleSystemBack());
  }

  aboutToDisappear(): void {
    this.onRegisterBackHandler(() => false);
  }

  private get sizeClass(): WindowSizeClass {
    return ResponsiveContext.resolve(this.widthVp);
  }

  private get contentWidthVp(): number {
    return this.sizeClass === WindowSizeClass.EXPANDED ?
      Math.max(0, this.widthVp - AppTheme.SIDE_NAV_WIDTH) : this.widthVp;
  }

  private get contentSizeClass(): WindowSizeClass {
    return ResponsiveContext.resolveContent(this.contentWidthVp);
  }

  private isDetailFlow(): boolean {
    return this.role === AppRole.PARENT && this.parentRoute === ParentRoute.CONFIRMATION;
  }

  private handleSystemBack(): boolean {
    if (this.navPathStack.size() > 0) {
      this.navPathStack.pop();
      return true;
    }
    if (this.role === AppRole.PARENT && this.parentRoute === ParentRoute.CONFIRMATION) {
      this.parentRoute = ParentRoute.IMPORT;
      return true;
    }
    return false;
  }

  private nextDemoScenario(): void {
    this.demoScenario = DemoScenarioHelper.next(this.demoScenario);
  }

  private touchStore(): void {
    this.storeRevision++;
    HomeworkSyncService.instance.requestSync();
  }

  private switchStudent(): void {
    if (this.role !== AppRole.PARENT) return;
    let students: StudentProfile[] = HomeworkStore.instance.getStudents();
    if (students.length <= 1) return;
    let activeId = HomeworkStore.instance.getActiveStudentId();
    let activeIndex = -1;
    for (let i = 0; i < students.length; i++) {
      if (students[i].id === activeId) {
        activeIndex = i;
        break;
      }
    }
    let nextIndex = activeIndex < 0 || activeIndex + 1 >= students.length ? 0 : activeIndex + 1;
    if (HomeworkStore.instance.setActiveStudent(students[nextIndex].id)) {
      this.navPathStack.clear();
      this.studentRoute = StudentRoute.HOME;
      this.parentRoute = ParentRoute.DASHBOARD;
      this.touchStore();
    }
  }

  private openAssignmentDetail(assignmentId: string): void {
    this.navPathStack.pushPathByName(
      AppRoute.STUDENT_ASSIGNMENT_DETAIL, new AssignmentRouteParam(assignmentId));
  }

  private openStudy(assignmentId: string): void {
    this.navPathStack.pushPathByName(AppRoute.STUDENT_STUDY, new AssignmentRouteParam(assignmentId));
  }

  private openParentReview(assignmentId: string): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_REVIEW, new AssignmentRouteParam(assignmentId));
  }

  private openParentExtraCreate(): void {
    this.navPathStack.pushPathByName(AppRoute.PARENT_EXTRA_CREATE, new ParentExtraCreateRouteParam());
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
    } else if (this.studentRoute === StudentRoute.PROFILE) {
      StudentProfilePage({
        sizeClass: this.contentSizeClass,
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
          onBack: () => this.navPathStack.pop(),
          onStoreChanged: () => this.touchStore()
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
          onReviewed: () => this.touchStore()
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    } else if (name === AppRoute.PARENT_EXTRA_CREATE) {
      NavDestination() {
        ParentExtraAssignmentPage({
          onBack: () => this.navPathStack.pop(),
          onCreated: () => {
            this.touchStore();
            this.navPathStack.pop();
          }
        });
      }
      .hideTitleBar(true)
      .backgroundColor(AppTheme.BACKGROUND);
    }
  }

  @Builder
  private ParentContent() {
    if (this.parentRoute === ParentRoute.IMPORT) {
      HomeworkImportPage({
        sizeClass: this.contentSizeClass,
        revision: this.storeRevision,
        onOpenConfirmation: () => this.parentRoute = ParentRoute.CONFIRMATION,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.CONFIRMATION) {
      HomeworkConfirmationPage({
        sizeClass: this.contentSizeClass,
        revision: this.storeRevision,
        onBack: () => this.parentRoute = ParentRoute.IMPORT,
        onPublished: () => this.parentRoute = ParentRoute.DASHBOARD,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.PROGRESS) {
      ParentProgressPage({
        revision: this.storeRevision,
        onOpenReview: (assignmentId: string) => this.openParentReview(assignmentId),
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.SETTINGS) {
      BackendConnectionPage({
        sizeClass: this.contentSizeClass,
        onStoreChanged: () => this.touchStore()
      });
    } else {
      ParentDashboardPage({
        revision: this.storeRevision,
        onOpenImport: () => this.parentRoute = ParentRoute.IMPORT,
        onOpenExtra: () => this.openParentExtraCreate(),
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
        Text(HomeworkStore.instance.getStudent().name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(HomeworkStore.instance.getStudent().className)
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      if (HomeworkStore.instance.getStudents().length > 1) {
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
        .accessibilityText('切换孩子')
        .onClick(() => this.switchStudent());
      }
    }
    .width('100%')
    .height(AppTheme.CONTEXT_BAR_HEIGHT)
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING })
    .backgroundColor(AppTheme.BACKGROUND);
  }

  @Builder
  private BottomItem(symbol: Resource, label: string, active: boolean, action: () => void) {
    Column({ space: 4 }) {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontColor([active ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT]);
      Text(label)
        .fontSize(11)
        .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(active ? `${label}，当前页面` : label)
    .onClick(action);
  }

  @Builder
  private BottomNavigation() {
    Row() {
      if (this.role === AppRole.STUDENT) {
        this.BottomItem($r('sys.symbol.house'), '首页', this.studentRoute === StudentRoute.HOME,
          () => this.studentRoute = StudentRoute.HOME);
        this.BottomItem($r('sys.symbol.checkmark_square'), '作业', this.studentRoute === StudentRoute.ASSIGNMENTS,
          () => this.studentRoute = StudentRoute.ASSIGNMENTS);
        this.BottomItem($r('sys.symbol.gearshape'), '我的', this.studentRoute === StudentRoute.PROFILE,
          () => this.studentRoute = StudentRoute.PROFILE);
      } else {
        this.BottomItem($r('sys.symbol.house'), '首页', this.parentRoute === ParentRoute.DASHBOARD,
          () => this.parentRoute = ParentRoute.DASHBOARD);
        this.BottomItem($r('sys.symbol.plus_square'), '导入', this.parentRoute === ParentRoute.IMPORT,
          () => this.parentRoute = ParentRoute.IMPORT);
        this.BottomItem($r('sys.symbol.checkmark_circle'), '进度', this.parentRoute === ParentRoute.PROGRESS,
          () => this.parentRoute = ParentRoute.PROGRESS);
        this.BottomItem($r('sys.symbol.gearshape'), '我的', this.parentRoute === ParentRoute.SETTINGS,
          () => this.parentRoute = ParentRoute.SETTINGS);
      }
    }
    .width('100%')
    .height(AppTheme.BOTTOM_NAV_HEIGHT)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
  }

  @Builder
  private SideItem(symbol: Resource, label: string, active: boolean, action: () => void) {
    Column({ space: 5 }) {
      SymbolGlyph(symbol)
        .fontSize(23)
        .fontColor([active ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT]);
      Text(label)
        .fontSize(11)
        .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .width(68)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(active ? AppTheme.PRIMARY_SOFT : Color.Transparent)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(active ? `${label}，当前页面` : label)
    .onClick(action);
  }

  @Builder
  private SideNavigation() {
    Column({ space: 8 }) {
      Text('伴')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .width(46)
        .height(46)
        .textAlign(TextAlign.Center)
        .padding({ top: 11 })
        .backgroundColor(AppTheme.PRIMARY)
        .borderRadius(15)
        .margin({ bottom: 14 });

      if (this.role === AppRole.STUDENT) {
        this.SideItem($r('sys.symbol.house'), '首页', this.studentRoute === StudentRoute.HOME,
          () => this.studentRoute = StudentRoute.HOME);
        this.SideItem($r('sys.symbol.checkmark_square'), '作业', this.studentRoute === StudentRoute.ASSIGNMENTS,
          () => this.studentRoute = StudentRoute.ASSIGNMENTS);
        this.SideItem($r('sys.symbol.gearshape'), '我的', this.studentRoute === StudentRoute.PROFILE,
          () => this.studentRoute = StudentRoute.PROFILE);
      } else {
        this.SideItem($r('sys.symbol.house'), '首页', this.parentRoute === ParentRoute.DASHBOARD,
          () => this.parentRoute = ParentRoute.DASHBOARD);
        this.SideItem($r('sys.symbol.plus_square'), '导入', this.parentRoute === ParentRoute.IMPORT,
          () => this.parentRoute = ParentRoute.IMPORT);
        this.SideItem($r('sys.symbol.checkmark_circle'), '进度', this.parentRoute === ParentRoute.PROGRESS,
          () => this.parentRoute = ParentRoute.PROGRESS);
        this.SideItem($r('sys.symbol.gearshape'), '我的', this.parentRoute === ParentRoute.SETTINGS,
          () => this.parentRoute = ParentRoute.SETTINGS);
      }

      Blank();

      if (this.role === AppRole.PARENT) {
        Column({ space: 2 }) {
          Text(HomeworkStore.instance.getStudent().name)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          Text(HomeworkStore.instance.getStudent().className)
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
        .accessibilityText('切换孩子')
        .onClick(() => this.switchStudent());
      } else {
        Text(HomeworkStore.instance.getStudent().name)
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
      if (this.role === AppRole.PARENT && !this.isDetailFlow()) {
        this.FamilyContextBar();
      }
      Column() {
        this.PersonaContent();
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);

      if (!this.isDetailFlow()) {
        this.BottomNavigation();
      }
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
      if (this.isDetailFlow()) {
        this.BottomNavShell();
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
