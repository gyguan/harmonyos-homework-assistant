import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { AppSettings, StudentProfile } from '../../../domain/model/HomeworkModels';

@Component
export struct StudentProfilePage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;

  private student(): StudentProfile {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudent();
  }

  private settings(): AppSettings {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getSettings();
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(72)
        .fontSize(AppTheme.BODY_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Text(value.length > 0 ? value : '未设置')
        .layoutWeight(1)
        .fontSize(AppTheme.BODY_SIZE)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 });
  }

  @Builder
  private RuleRow(title: string, description: string, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .width('100%')
          .fontSize(AppTheme.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(description)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(enabled ? '已开启' : '已关闭')
        .fontSize(AppTheme.CAPTION_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? AppTheme.SUCCESS : AppTheme.SUBTEXT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(enabled ? AppTheme.SUCCESS_SOFT : AppTheme.SURFACE_EMPHASIS)
        .borderRadius(AppTheme.CHIP_RADIUS);
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 });
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('我的')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('这里只展示你的学习信息和家长设置，不需要你管理作业。')
            .fontSize(AppTheme.BODY_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: 12 }) {
          Row({ space: 14 }) {
            Text(this.student().name.length > 0 ? this.student().name.substring(0, 1) : '伴')
              .width(52)
              .height(52)
              .padding({ top: 13 })
              .textAlign(TextAlign.Center)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .backgroundColor(AppTheme.PRIMARY)
              .borderRadius(18);
            Column({ space: 4 }) {
              Text(this.student().name)
                .fontSize(AppTheme.SECTION_TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT);
              Text(`${this.student().grade} · ${this.student().className}`)
                .fontSize(AppTheme.BODY_SIZE)
                .fontColor(AppTheme.SUBTEXT);
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%');

          Divider().color(AppTheme.DIVIDER);
          this.InfoRow('学期', this.student().semester);
          this.InfoRow('教材', this.student().textbookSummary);
        }
        .width('100%')
        .padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CARD_RADIUS);

        Column({ space: 8 }) {
          Text('AI 辅导规则')
            .width('100%')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('这些规则由家长设置，小伴会按规则陪你思考。')
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          Divider().color(AppTheme.DIVIDER);
          this.RuleRow(
            '引导优先',
            this.settings().tutorGuidanceFirst ? '先提示思路，再一步一步讲解。' : '可以更直接地解释解题方法。',
            this.settings().tutorGuidanceFirst
          );
          Divider().color(AppTheme.DIVIDER);
          this.RuleRow(
            '直接答案',
            this.settings().directAnswerAllowed ? '家长已允许在需要时展示直接答案。' : '默认不直接给答案，先帮助你自己想出来。',
            this.settings().directAnswerAllowed
          );
        }
        .width('100%')
        .padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CARD_RADIUS);

        Column({ space: 6 }) {
          Text('需要修改资料？')
            .width('100%')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('姓名、年级、班级、学期、教材和云端连接都由家长在家长空间管理。学生空间不会切换到其他家庭成员。')
            .width('100%')
            .fontSize(AppTheme.BODY_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
