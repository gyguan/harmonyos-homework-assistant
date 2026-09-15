import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, StudentProfile, TodaySummary } from '../../../domain/model/HomeworkModels';

@Component
export struct ParentDashboardPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  onOpenImport: () => void = () => {};

  private student(): StudentProfile {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudent();
  }

  private summary(): TodaySummary {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getTodaySummary();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  @Builder
  private TodaySummary() {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text('今日完成').fontSize(12).fontColor(AppTheme.SUBTEXT);
        Row({ space: 6 }) {
          Text(`${this.summary().completed}`).fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`/ ${this.summary().total}`).fontSize(15).fontColor(AppTheme.SUBTEXT).margin({ top: 10 });
        }
      }.alignItems(HorizontalAlign.Start);
      Column({ space: 8 }) {
        Row() {
          Text(this.summary().completed === this.summary().total && this.summary().total > 0 ? '今天已完成' : '今天进行中')
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.summary().completed === this.summary().total && this.summary().total > 0 ? AppTheme.SUCCESS : AppTheme.PRIMARY);
          Blank();
          Text(`${this.assignments().length} 项作业`).fontSize(12).fontColor(AppTheme.SUBTEXT);
        }.width('100%');
        Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
          .width('100%').height(7).color(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT);
        Text('关注完成和提交结果，不需要一直盯着孩子做作业。').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
    }
    .width('100%').padding(16).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private AssignmentProgress() {
    Column({ space: 10 }) {
      Row() {
        Text('今天的作业').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.assignments().length} 项`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Column({ space: 7 }) {
        ForEach(this.assignments(), (item: Assignment) => {
          AssignmentListItem({ assignment: item, showChevron: false, interactive: false });
        }, (item: Assignment) => item.id);
      }.width('100%');
    }.width('100%');
  }

  @Builder
  private ImportAction() {
    Row({ space: 13 }) {
      SymbolGlyph($r('sys.symbol.plus_square')).fontSize(24).fontColor([AppTheme.PRIMARY]);
      Column({ space: 4 }) {
        Text(`给 ${this.student().name} 收作业`).width('100%').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('导入老师作业：把截图或文字交给小伴，整理后再确认发布。')
          .width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding(15)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`给 ${this.student().name} 收作业，导入老师作业`)
    .onClick(() => this.onOpenImport());
  }

  @Builder
  private PageHeader() {
    Column({ space: 5 }) {
      Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      Text(`${this.student().name} · ${this.student().grade} · ${this.student().className} · ${this.student().semester}`)
        .fontSize(13).fontColor(AppTheme.SUBTEXT);
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder
  private PhoneHeader() {
    Column({ space: 2 }) {
      Text(`${this.student().name} 的作业`).fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
        .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      Text(`${this.student().grade} · ${this.student().className}`)
        .fontSize(12).fontColor(AppTheme.SUBTEXT);
    }
    .width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder
  private PhoneSummary() {
    Column({ space: 9 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今天').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Row({ space: 5 }) {
            Text(`${this.summary().completed}`).fontSize(27).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            Text(`/ ${this.summary().total} 已完成`).fontSize(13).fontColor(AppTheme.SUBTEXT).margin({ top: 8 });
          }
        }.alignItems(HorizontalAlign.Start);
        Blank();
        Text(this.summary().completed === this.summary().total && this.summary().total > 0 ? '全部完成' : '进行中')
          .fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.summary().completed === this.summary().total && this.summary().total > 0 ? AppTheme.SUCCESS : AppTheme.PRIMARY)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor(this.summary().completed === this.summary().total && this.summary().total > 0 ? AppTheme.SUCCESS_SOFT : AppTheme.PRIMARY_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS);
      }.width('100%');
      Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
        .width('100%').height(7).color(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT);
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private PhoneImportAction() {
    Row({ space: 11 }) {
      SymbolGlyph($r('sys.symbol.plus_square')).fontSize(22).fontColor([AppTheme.PRIMARY]);
      Column({ space: 2 }) {
        Text('导入老师作业').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('截图或文字，整理后再确认').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 13, right: 13, top: 11, bottom: 11 })
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`给 ${this.student().name} 收作业，导入老师作业`)
    .onClick(() => this.onOpenImport());
  }

  @Builder
  private PhoneAssignments() {
    Column({ space: 9 }) {
      Row() {
        Text('今天的作业').fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.assignments().length} 项`).fontSize(11).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      if (this.assignments().length === 0) {
        Text('还没有发布作业').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT)
          .padding({ top: 18, bottom: 18 }).textAlign(TextAlign.Center);
      } else {
        Column({ space: 6 }) {
          ForEach(this.assignments(), (item: Assignment) => {
            AssignmentListItem({ assignment: item, showChevron: false, interactive: false });
          }, (item: Assignment) => item.id);
        }.width('100%');
      }
    }.width('100%');
  }

  @Builder
  private PhoneLayout() {
    Scroll() {
      Column({ space: AppTheme.PHONE_SECTION_GAP }) {
        this.PhoneHeader();
        this.PhoneSummary();
        this.PhoneImportAction();
        this.PhoneAssignments();
      }
      .width('100%')
      .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING, top: 14, bottom: 18 });
    }
    .width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND).scrollBar(BarState.Off);
  }

  @Builder
  private PadLayout() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        this.PageHeader();
        this.TodaySummary();
        Row({ space: 20 }) {
          Column({ space: 18 }) {
            this.AssignmentProgress();
          }
          .width(this.sizeClass === WindowSizeClass.EXPANDED ? '62%' : '58%');
          Column({ space: 14 }) {
            this.ImportAction();
            Column({ space: 5 }) {
              Text('家长只需关注结果').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
              Text('孩子开始、暂停、提交后，状态会同步到这里；待验收时再进入“进度”处理。')
                .width('100%').fontSize(13).lineHeight(20).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%').padding(15).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
          }
          .layoutWeight(1);
        }
        .width('100%').alignItems(VerticalAlign.Top);
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }

  build() {
    if (this.sizeClass === WindowSizeClass.COMPACT) {
      this.PhoneLayout();
    } else {
      this.PadLayout();
    }
  }
}
