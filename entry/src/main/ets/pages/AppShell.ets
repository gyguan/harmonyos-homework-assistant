import { ResponsiveContext, WindowSizeClass } from '../common/responsive/WindowSizeClass';
import { AppTheme } from '../common/theme/AppTheme';
import { HomeworkImportPage } from '../features/parent/import/HomeworkImportPage';
import { ParentDashboardPage } from '../features/parent/dashboard/ParentDashboardPage';
import { StudyWorkspacePage } from '../features/student/study/StudyWorkspacePage';
import { StudentTodayPage } from '../features/student/today/StudentTodayPage';

enum AppRole {
  STUDENT = 'STUDENT',
  PARENT = 'PARENT'
}

enum StudentRoute {
  TODAY = 'TODAY',
  STUDY = 'STUDY'
}

enum ParentRoute {
  DASHBOARD = 'DASHBOARD',
  IMPORT = 'IMPORT'
}

@Component
export struct AppShell {
  @State private widthVp: number = 390;
  @State private heightVp: number = 844;
  @State private role: AppRole = AppRole.STUDENT;
  @State private studentRoute: StudentRoute = StudentRoute.TODAY;
  @State private parentRoute: ParentRoute = ParentRoute.DASHBOARD;

  private navPathStack: NavPathStack = new NavPathStack();

  private get sizeClass(): WindowSizeClass {
    return ResponsiveContext.resolve(this.widthVp);
  }

  @Builder
  private RoleContent() {
    if (this.role === AppRole.STUDENT) {
      if (this.studentRoute === StudentRoute.STUDY) {
        StudyWorkspacePage({
          sizeClass: this.sizeClass,
          onBack: () => this.studentRoute = StudentRoute.TODAY
        });
      } else {
        StudentTodayPage({
          sizeClass: this.sizeClass,
          onOpenStudy: () => this.studentRoute = StudentRoute.STUDY
        });
      }
    } else {
      if (this.parentRoute === ParentRoute.IMPORT) {
        HomeworkImportPage({ sizeClass: this.sizeClass });
      } else {
        ParentDashboardPage({ sizeClass: this.sizeClass });
      }
    }
  }

  @Builder
  private RoleSwitch() {
    Row() {
      Text(this.role === AppRole.STUDENT ? '学生空间' : '家长空间')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Blank();
      Text(this.role === AppRole.STUDENT ? '切换家长' : '切换学生')
        .fontSize(13)
        .fontColor(AppTheme.PRIMARY)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(14)
        .onClick(() => {
          this.role = this.role === AppRole.STUDENT ? AppRole.PARENT : AppRole.STUDENT;
        });
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
        this.NavText('学习', this.studentRoute === StudentRoute.STUDY, () => this.studentRoute = StudentRoute.STUDY);
        this.NavText('教材', false, () => {});
        this.NavText('我的', false, () => {});
      } else {
        this.NavText('首页', this.parentRoute === ParentRoute.DASHBOARD, () => this.parentRoute = ParentRoute.DASHBOARD);
        this.NavText('导入', this.parentRoute === ParentRoute.IMPORT, () => this.parentRoute = ParentRoute.IMPORT);
        this.NavText('进度', false, () => {});
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
        this.SideItem('学习', this.studentRoute === StudentRoute.STUDY, () => this.studentRoute = StudentRoute.STUDY);
        this.SideItem('教材', false, () => {});
      } else {
        this.SideItem('首页', this.parentRoute === ParentRoute.DASHBOARD, () => this.parentRoute = ParentRoute.DASHBOARD);
        this.SideItem('导入', this.parentRoute === ParentRoute.IMPORT, () => this.parentRoute = ParentRoute.IMPORT);
        this.SideItem('进度', false, () => {});
      }

      Blank();
      Text(this.role === AppRole.STUDENT ? '家长' : '学生')
        .fontSize(12)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.role = this.role === AppRole.STUDENT ? AppRole.PARENT : AppRole.STUDENT);
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
  private CompactShell() {
    Column() {
      this.RoleSwitch();
      Column() { this.RoleContent(); }.width('100%').layoutWeight(1);
      this.BottomNavigation();
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private WideShell() {
    Row() {
      this.SideNavigation();
      Column() { this.RoleContent(); }.layoutWeight(1).height('100%');
    }
    .width('100%')
    .height('100%');
  }

  build() {
    Stack() {
      if (this.sizeClass === WindowSizeClass.COMPACT) {
        this.CompactShell();
      } else {
        this.WideShell();
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
}
