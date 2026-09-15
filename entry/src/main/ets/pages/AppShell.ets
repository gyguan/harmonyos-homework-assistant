import { HomeworkSyncService } from '../application/remote/HomeworkSyncService';
import { ResponsiveContext, WindowSizeClass } from '../common/responsive/WindowSizeClass';
import { DemoScenario, DemoScenarioHelper } from '../common/state/DemoScenario';
import { AppTheme } from '../common/theme/AppTheme';
import { PageStateView } from '../components/state/PageStateView';
import { HomeworkStore } from '../data/HomeworkStore';
import { StudentProfile } from '../domain/model/HomeworkModels';
import { HomeworkConfirmationPage } from '../features/parent/confirmation/HomeworkConfirmationPage';
import { ParentDashboardPage } from '../features/parent/dashboard/ParentDashboardPage';
import { HomeworkImportPage } from '../features/parent/import/HomeworkImportPage';
import { ParentProgressPage } from '../features/parent/progress/ParentProgressPage';
import { BackendConnectionPage } from '../features/parent/settings/BackendConnectionPage';
import { StudentAssignmentsPage } from '../features/student/assignments/StudentAssignmentsPage';
import { StudentProfilePage } from '../features/student/profile/StudentProfilePage';
import { StudyWorkspacePage } from '../features/student/study/StudyWorkspacePage';
import { StudentTodayPage } from '../features/student/today/StudentTodayPage';

export enum AppRole {
  NONE = 'NONE',
  STUDENT = 'STUDENT',
  PARENT = 'PARENT'
}

enum StudentRoute {
  TODAY = 'TODAY',
  ASSIGNMENTS = 'ASSIGNMENTS',
  PROFILE = 'PROFILE',
  STUDY = 'STUDY'
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
  @State private studentRoute: StudentRoute = StudentRoute.TODAY;
  @State private studentStudyReturnRoute: StudentRoute = StudentRoute.TODAY;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;
  @State private demoScenario: DemoScenario = DemoScenario.NORMAL;
  @State private selectedAssignmentId: string = '';
  @State private storeRevision: number = 0;

  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

  private get sizeClass(): WindowSizeClass {
    return ResponsiveContext.resolve(this.widthVp);
  }

  private isDetailFlow(): boolean {
    if (this.role === AppRole.STUDENT) return this.studentRoute === StudentRoute.STUDY;
    return this.parentRoute === ParentRoute.CONFIRMATION;
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
      this.selectedAssignmentId = '';
      this.studentRoute = StudentRoute.TODAY;
      this.parentRoute = ParentRoute.DASHBOARD;
      this.touchStore();
    }
  }

  private openStudy(assignmentId: string): void {
    HomeworkStore.instance.startAssignment(assignmentId);
    this.selectedAssignmentId = assignmentId;
    this.studentStudyReturnRoute = this.studentRoute === StudentRoute.ASSIGNMENTS ? StudentRoute.ASSIGNMENTS : StudentRoute.TODAY;
    this.touchStore();
    this.studentRoute = StudentRoute.STUDY;
  }

  private isBlockingPageState(): boolean {
    return this.demoScenario === DemoScenario.LOADING ||
      this.demoScenario === DemoScenario.EMPTY ||
      this.demoScenario === DemoScenario.ERROR;
  }

  @Builder
  private StudentContent() {
    if (this.studentRoute === StudentRoute.STUDY) {
      StudyWorkspacePage({
        sizeClass: this.sizeClass,
        tutorUnavailable: this.demoScenario === DemoScenario.TUTOR_UNAVAILABLE,
        assignmentId: this.selectedAssignmentId,
        revision: this.storeRevision,
        onBack: () => this.studentRoute = this.studentStudyReturnRoute,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.studentRoute === StudentRoute.ASSIGNMENTS) {
      StudentAssignmentsPage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision,
        onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
      });
    } else if (this.studentRoute === StudentRoute.PROFILE) {
      StudentProfilePage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision
      });
    } else {
      StudentTodayPage({
        sizeClass: this.sizeClass,
        offlineMode: this.demoScenario === DemoScenario.OFFLINE,
        revision: this.storeRevision,
        onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
      });
    }
  }

  @Builder
  private ParentContent() {
    if (this.parentRoute === ParentRoute.IMPORT) {
      HomeworkImportPage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision,
        onOpenConfirmation: () => this.parentRoute = ParentRoute.CONFIRMATION,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.CONFIRMATION) {
      HomeworkConfirmationPage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision,
        onBack: () => this.parentRoute = ParentRoute.IMPORT,
        onPublished: () => this.parentRoute = ParentRoute.DASHBOARD,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.PROGRESS) {
      ParentProgressPage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision,
        onStoreChanged: () => this.touchStore()
      });
    } else if (this.parentRoute === ParentRoute.SETTINGS) {
      BackendConnectionPage({ onStoreChanged: () => this.touchStore() });
    } else {
      ParentDashboardPage({
        sizeClass: this.sizeClass,
        revision: this.storeRevision,
        onOpenImport: () => this.parentRoute = ParentRoute.IMPORT
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
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS)
        .onClick(() => this.switchStudent());
      }
    }
    .width('100%')
    .height(48)
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
    .onClick(action);
  }

  @Builder
  private BottomNavigation() {
    Row() {
      if (this.role === AppRole.STUDENT) {
        this.BottomItem($r('sys.symbol.checkmark_circle'), '今天', this.studentRoute === StudentRoute.TODAY,
          () => this.studentRoute = StudentRoute.TODAY);
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
        this.SideItem($r('sys.symbol.checkmark_circle'), '今天', this.studentRoute === StudentRoute.TODAY,
          () => this.studentRoute = StudentRoute.TODAY);
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
            .fontSize(9)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width(68)
        .padding({ top: 8, bottom: 8 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(AppTheme.CHIP_RADIUS)
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

      Text(DemoScenarioHelper.label(this.demoScenario))
        .width(68)
        .fontSize(9)
        .textAlign(TextAlign.Center)
        .fontColor(AppTheme.TERTIARY_TEXT)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => this.nextDemoScenario());
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
      .layoutWeight(1);

      if (!this.isDetailFlow()) {
        this.BottomNavigation();
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private SideNavShell() {
    Row() {
      this.SideNavigation();
      Column() {
        this.PersonaContent();
      }
      .layoutWeight(1)
      .height('100%');
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private ShellContent() {
    Stack() {
      if (this.sizeClass === WindowSizeClass.EXPANDED) {
        this.SideNavShell();
      } else {
        this.BottomNavShell();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.widthVp = Number(newValue.width);
      this.heightVp = Number(newValue.height);
    });
  }

  build() {
    Navigation(this.navPathStack) {
      this.ShellContent();
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .width('100%')
    .height('100%');
  }
}
