import { AppTheme } from '../../../common/theme/AppTheme';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { ReadonlySettingStateRow } from '../../../components/selection/SelectionControls';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { AppSettings, StudentProfile } from '../../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

@Component
export struct StudentProfilePage {
  @Prop revision: number = 0;
  @State private learningInfoExpanded: boolean = false;
  @State private tutorRulesExpanded: boolean = false;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;

  private student(): StudentProfile {
    let currentRevision = this.revision;
    return this.familyContext.getStudent();
  }

  private settings(): AppSettings {
    let currentRevision = this.revision;
    return this.familyContext.getSettings();
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(72)
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      Text(value.length > 0 ? value : '未设置')
        .layoutWeight(1)
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 });
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 18 }) {
          Row({ space: 14 }) {
            CenteredTextBadge({
              badgeText: this.student().name.length > 0 ? this.student().name.substring(0, 1) : '伴',
              badgeWidth: 52,
              badgeHeight: 52,
              badgeFontSize: 20,
              badgeRadius: 18,
              badgeBold: true,
              badgeForeground: AppTheme.TEXT_ON_PRIMARY,
              badgeBackground: AppTheme.PRIMARY
            });
            Column({ space: 4 }) {
              Text(this.student().name)
                .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
                .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
                .fontWeight(FontWeight.Bold)
                .maxLines(AppTheme.NAV_TITLE_MAX_LINES)
                .fontColor(AppTheme.TEXT);
              Text(`${this.student().grade} · ${this.student().className}`)
                .fontSize(AppTheme.BODY_SIZE)
                .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                .fontColor(AppTheme.SUBTEXT);
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 });

          Column() {
            Column({ space: 2 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('学习资料')
                    .fontSize(AppTheme.CARD_TITLE_SIZE)
                    .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
                    .fontColor(AppTheme.TEXT);
                  Text('学期和教材')
                    .fontSize(AppTheme.CAPTION_SIZE)
                    .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
                Text(this.learningInfoExpanded ? '收起' : '查看')
                  .fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.PRIMARY);
              }
              .width('100%')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .alignItems(VerticalAlign.Center)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText(this.learningInfoExpanded ? '收起学习资料' : '查看学习资料')
              .onClick(() => this.learningInfoExpanded = !this.learningInfoExpanded);

              if (this.learningInfoExpanded) {
                this.InfoRow('学期', this.student().semester);
                Divider().color(AppTheme.DIVIDER);
                this.InfoRow('教材', this.student().textbookSummary);
              }
            }
            .width('100%')
            .padding(16);

            Divider().color(AppTheme.DIVIDER);

            Column({ space: 2 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('小伴规则')
                    .fontSize(AppTheme.CARD_TITLE_SIZE)
                    .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
                    .fontColor(AppTheme.TEXT);
                  Text('AI 辅导规则由家长设置')
                    .fontSize(AppTheme.CAPTION_SIZE)
                    .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                    .fontColor(AppTheme.SUBTEXT);
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);
                Text(this.tutorRulesExpanded ? '收起' : '查看')
                  .fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.PRIMARY);
              }
              .width('100%')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .alignItems(VerticalAlign.Center)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText(this.tutorRulesExpanded ? '收起小伴规则' : '查看小伴规则')
              .onClick(() => this.tutorRulesExpanded = !this.tutorRulesExpanded);

              if (this.tutorRulesExpanded) {
                ReadonlySettingStateRow({
                  title: '引导优先',
                  description: this.settings().tutorGuidanceFirst ?
                    '先提示思路，再一步一步讲解。' : '可以更直接地解释解题方法。',
                  isEnabled: this.settings().tutorGuidanceFirst
                });
                Divider().color(AppTheme.DIVIDER);
                ReadonlySettingStateRow({
                  title: '直接答案',
                  description: this.settings().directAnswerAllowed ?
                    '家长已允许在需要时展示直接答案。' : '默认不直接给答案，先帮助你自己想出来。',
                  isEnabled: this.settings().directAnswerAllowed
                });
              }
            }
            .width('100%')
            .padding(16);
          }
          .width('100%')
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CARD_RADIUS);

          Text('学习资料和小伴规则都由家长维护。')
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
