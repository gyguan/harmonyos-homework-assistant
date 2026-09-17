import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { AppSettings, StudentProfile } from '../../../domain/model/HomeworkModels';

@Component
export struct StudentProfilePage {
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
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
      Text(value.length > 0 ? value : '未设置')
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 });
  }

  @Builder
  private RuleRow(title: string, description: string, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(description)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(enabled ? '已开启' : '已关闭')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 });
  }

  @Builder
  private SectionTitle(title: string, description: string) {
    Column({ space: 3 }) {
      Text(title)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(description)
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 20 }) {
          Column({ space: 5 }) {
            Text('我的')
              .fontSize(AppTheme.PAGE_TITLE_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
            Text('这里展示你的学习资料和家长设置。')
              .fontSize(AppTheme.BODY_SIZE)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

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
          .width('100%')
          .padding({ top: 4, bottom: 4 });

          Column({ space: 10 }) {
            this.SectionTitle('学习资料', '学期和教材由家长维护。');
            Column() {
              this.InfoRow('学期', this.student().semester);
              Divider().color(AppTheme.DIVIDER);
              this.InfoRow('教材', this.student().textbookSummary);
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }
          .width('100%');

          Column({ space: 10 }) {
            this.SectionTitle('AI 辅导规则', '这些规则由家长设置，小伴会按规则陪你思考。');
            Column() {
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
            .padding({ left: 16, right: 16 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }
          .width('100%');

          Text('需要修改姓名、年级、班级、学期或教材时，请由家长在家长空间中调整。')
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor(AppTheme.SUBTEXT)
            .padding({ left: 4, right: 4 });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PROFILE_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
