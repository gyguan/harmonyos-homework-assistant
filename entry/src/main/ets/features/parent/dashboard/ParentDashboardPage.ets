import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
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
  private TodayCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 5 }) {
          Text(`${this.student().name} · 今日完成`)
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          Text(`${this.summary().completed} / ${this.summary().total}`)
            .width('100%')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text(this.summary().completed === this.summary().total && this.summary().total > 0 ? '已完成' : '进行中')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.summary().completed === this.summary().total && this.summary().total > 0 ? AppTheme.SUCCESS : AppTheme.PRIMARY)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.summary().completed === this.summary().total && this.summary().total > 0 ? AppTheme.SUCCESS_SOFT : AppTheme.PRIMARY_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%');

      Progress({ value: this.summary().completed, total: this.summary().total, type: ProgressType.Linear })
        .width('100%')
        .height(7)
        .color(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT);

      Text('只看今天的完成和提交情况，不需要一直盯着孩子做作业。')
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(21)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private AssignmentProgress() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Row() {
        Text('今天的作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.assignments().length} 项`)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private ImportCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.plus_square'))
          .fontSize(24)
          .fontColor([AppTheme.PRIMARY]);
        Text(`给 ${this.student().name} 收作业`)
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%');
      Text(`${this.student().className} · 把老师发来的文字或截图交给小伴，确认后只进入 ${this.student().name} 的作业空间。`)
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(22)
        .fontColor(AppTheme.SUBTEXT);
      Button('导入老师作业', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.onOpenImport());
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('作业进度')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(`${this.student().name} · ${this.student().grade} · ${this.student().className} · ${this.student().semester}`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        this.TodayCard();

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 20 }) {
            Column() { this.AssignmentProgress(); }.width('64%');
            Column() { this.ImportCard(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.AssignmentProgress();
          this.ImportCard();
        }
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
