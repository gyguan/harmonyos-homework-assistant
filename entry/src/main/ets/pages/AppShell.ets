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
import { StudyWorkspacePage } from '../features/student/study/StudyWorkspacePage';
import { StudentTodayPage } from '../features/student/today/StudentTodayPage';

export enum AppRole {
  NONE = 'NONE',
  STUDENT = 'STUDENT',
  PARENT = 'PARENT'
}

enum StudentRoute {
  TODAY = 'TODAY',
  STUDY = 'STUDY'
}

enum ParentRoute {
  DASHBOARD = 'DASHBOARD',
  IMPORT = 'IMPORT',
  CONFIRMATION = 'CONFIRMATION',
  PROGRESS = 'PROGRESS'
}

@Component
export struct AppShell {
  @Prop role: AppRole = AppRole.STUDENT;
  @State private widthVp: number = 390;
  @State private heightVp: number = 844;
  @State private studentRoute: StudentRoute = StudentRoute.TODAY;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;
  @State private demoScenario: DemoScenario = DemoScenario.NORMAL;
  @State private selectedAssignmentId: string = '';
  @State private storeRevision: number = 0;

  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

  private get sizeClass(): WindowSizeClass {
    return ResponsiveContext.resolve(this.widthVp);
  }

  private nextDemoScenario(): void {
    this.demoScenario = DemoScenarioHelper.next(this.demoScenario);
  }

  private touchStore(): void {
    this.storeRevision++;
  }

  private switchStudent(): void {
    if (this.role !== AppRole.PARENT) {
      return;
    }
    let students: StudentProfile[] = HomeworkStore.instance.getStudents();
    if (students.length <= 1) {
      return;
    }
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
    this.touchStore();
    this.studentRoute = StudentRoute.STUDY;
  }

  private isBlockingPageState(): boolean {
    return this.demoScenario === DemoScenario.LOADING ||
      this.demoScenario === DemoScenario.EMPTY ||
      this.demoScenario === DemoScenario.ERROR;
  }

  @Builder
  private PersonaContent() {
    if (this.isBlockingPageState()) {
      PageStateView({ scenario: this.demoScenario });
    } else if (this.role === AppRole.STUDENT) {
      if (this.studentRoute === StudentRoute.STUDY) {
        StudyWorkspacePage({
          sizeClass: this.sizeClass,
          tutorUnavailable: this.demoScenario === DemoScenario.TUTOR_UNAVAILABLE,
          assignmentId: this.selectedAssignmentId,
          revision: this.storeRevision,
          onBack: () => this.studentRoute = StudentRoute.TODAY,
          onStoreChanged: () => this.touchStore()
        });
      } else {
        StudentTodayPage({
          sizeClass: this.sizeClass,
          offlineMode: this.demoScenario === DemoScenario.OFFLINE,
          revision: this.storeRevision,
          onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)
        });
      }
    } else {
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
          revision: this.storeRevision
        });
      } else {
        ParentDashboardPage({
          sizeClass: this.sizeClass,
          revision: this.storeRevision,
          onOpenImport: () => this.parentRoute = ParentRoute.IMPORT
        });
      }
    }
  }

  @Builder
  private ScenarioChip() {
    Text(`演示：${DemoScenarioHelper.label(this.demoScenario)}`)
      .fontSize(12)
      .fontColor(AppTheme.PRIMARY)
      .padding({ left: 10, right: 10, top: 7, bottom: 7 })
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .borderRadius(12)
      .onClick(() => this.nextDemoScenario());
  }

  @Builder
  private ParentChildChip() {
    Text(`${HomeworkStore.instance.getStudent().name} · ${HomeworkStore.instance.getStudent().className}`)
      .fontSize(12)
      .fontColor(AppTheme.PRIMARY)
      .padding({ left: 10, right: 10, top: 7, bottom: 7 })
      .backgroundColor(AppTheme.PRIMARY_SOFT)
      .borderRadius(12)
      .onClick(() => this.switchStudent());
  }

  @Builder
  private StudentIdentityChip() {
    Text(`${HomeworkStore.instance.getStudent().name} · ${HomeworkStore.instance.getStudent().className}`)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.TEXT)
      .padding({ left: 10, right: 10, top: 7, bottom: 7 })
      .backgroundColor('#F4F6F8')
      .borderRadius(12);
  }

  @Builder
  private ContextBar() {
    Row({ space: 8 }) {
      Text(this.role === AppRole.PARENT ? '家长空间' : '学生空间')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Blank();
      if (this.role === AppRole.PARENT) {
        this.ParentChildChip();
      } else {
        this.StudentIdentityChip();
      }
      if (this.widthVp > 420) {
        this.ScenarioChip();
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 18, right: 18 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { bottom: 1 }, color: AppTheme.BORDER });
  }

  @Builder
  private BottomNavigation() {
    Row() {
      if (this.role === AppRole.STUDENT) {
        this.NavText('今天', this.studentRoute === StudentRoute.TODAY, () => this.studentRoute = StudentRoute.TODAY);
        this.NavText('作业', this.studentRoute === StudentRoute.STUDY, () => this.studentRoute = StudentRoute.STUDY);
        this.NavText('我的', false, () => {});
      } else {
        this.NavText('首页', this.parentRoute === ParentRoute.DASHBOARD, () => this.parentRoute = ParentRoute.DASHBOARD);
        this.NavText('导入', this.parentRoute === ParentRoute.IMPORT || this.parentRoute === ParentRoute.CONFIRMATION,
          () => this.parentRoute = ParentRoute.IMPORT);
        this.NavText('进度', this.parentRoute === ParentRoute.PROGRESS, () => this.parentRoute = ParentRoute.PROGRESS);
        this.NavText('我的', false, () => {});
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 10, right: 10 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { top: 1 }, color: AppTheme.BORDER });
  }

  @Builder
  private NavText(label: string, active: boolean, action: () => void) {
    Column({ space: 3 }) {
      Text(active ? '●' : '○').fontSize(14).fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      Text(label).fontSize(11).fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(action);
  }

  @Builder
  private SideNavigation() {
    Column({ space: 8 }) {
      Text('伴')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .padding({ top: 11 })
        .backgroundColor(AppTheme.PRIMARY)
        .borderRadius(15)
        .margin({ bottom: 12 });

      if (this.role === AppRole.STUDENT) {
        this.SideItem('今天', this.studentRoute === StudentRoute.TODAY, () => this.studentRoute = StudentRoute.TODAY);
        this.SideItem('作业', this.studentRoute === StudentRoute.STUDY, () => this.studentRoute = StudentRoute.STUDY);
        this.SideItem('我的', false, () => {});
      } else {
        this.SideItem('首页', this.parentRoute === ParentRoute.DASHBOARD, () => this.parentRoute = ParentRoute.DASHBOARD);
        this.SideItem('导入', this.parentRoute === ParentRoute.IMPORT || this.parentRoute === ParentRoute.CONFIRMATION,
          () => this.parentRoute = ParentRoute.IMPORT);
        this.SideItem('进度', this.parentRoute === ParentRoute.PROGRESS, () => this.parentRoute = ParentRoute.PROGRESS);
        this.SideItem('我的', false, () => {});
      }

      Blank();
      if (this.role === AppRole.PARENT) {
        Text(HomeworkStore.instance.getStudent().name)
          .width(66)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.PRIMARY)
          .padding({ top: 7, bottom: 7 })
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(10)
          .onClick(() => this.switchStudent());
      } else {
        Text(HomeworkStore.instance.getStudent().name)
          .width(66)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.TEXT)
          .padding({ top: 7, bottom: 7 })
          .backgroundColor('#F4F6F8')
          .borderRadius(10);
      }
      Text(DemoScenarioHelper.label(this.demoScenario))
        .width(66)
        .fontSize(10)
        .textAlign(TextAlign.Center)
        .fontColor(AppTheme.SUBTEXT)
        .onClick(() => this.nextDemoScenario());
    }
    .width(88)
    .height('100%')
    .padding({ top: 18, bottom: 18 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { right: 1 }, color: AppTheme.BORDER });
  }

  @Builder
  private SideItem(label: string, active: boolean, action: () => void) {
    Text(label)
      .width(66)
      .height(42)
      .textAlign(TextAlign.Center)
      .padding({ top: 12 })
      .fontSize(12)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .backgroundColor(active ? AppTheme.PRIMARY_SOFT : Color.Transparent)
      .borderRadius(13)
      .onClick(action);
  }

  @Builder
  private BottomNavShell() {
    Column() {
      this.ContextBar();
      Column() { this.PersonaContent(); }.width('100%').layoutWeight(1);
      this.BottomNavigation();
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private SideNavShell() {
    Row() {
      this.SideNavigation();
      Column() { this.PersonaContent(); }.layoutWeight(1).height('100%');
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
