import { AppTheme } from '../common/theme/AppTheme';
import { CenteredTextBadge } from '../components/family/CenteredTextBadge';
import { DefaultFamilyContextRepository } from '../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../domain/port/FamilyContextRepository';

@Component
export struct PersonEntryPage {
  @Prop revision: number = 0;
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  onSelectParent: () => void = () => {};
  onSelectStudent: (studentId: string) => void = () => {};

  private students(): StudentProfile[] {
    let currentRevision = this.revision;
    return this.familyContext.getStudents();
  }

  @Builder
  private BrandHeader() {
    Column({ space: 10 }) {
      CenteredTextBadge({
        badgeText: '伴',
        badgeWidth: 52,
        badgeHeight: 52,
        badgeFontSize: 22,
        badgeRadius: 16,
        badgeBold: true,
        badgeForeground: AppTheme.TEXT_ON_PRIMARY,
        badgeBackground: AppTheme.PRIMARY
      });
      Text('小伴作业')
        .fontSize(AppTheme.PAGE_TITLE_SIZE)
        .lineHeight(AppTheme.PAGE_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text('今天是谁在使用？')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 18 });
  }

  @Builder
  private ParentRow() {
    Row({ space: 13 }) {
      CenteredTextBadge({
        badgeText: '家',
        badgeWidth: 40,
        badgeHeight: 40,
        badgeFontSize: 15,
        badgeRadius: 12,
        badgeBold: true,
        badgeForeground: AppTheme.TEXT_ON_PRIMARY,
        badgeBackground: AppTheme.PRIMARY
      });
      Column({ space: 3 }) {
        Text('家长')
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .fontColor(AppTheme.TEXT);
        Text('收作业、确认任务、查看孩子完成情况')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ top: 12, bottom: 12 })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('家长，收作业、确认任务、查看孩子完成情况')
    .onClick(() => this.onSelectParent());
  }

  @Builder
  private StudentRow(student: StudentProfile) {
    Row({ space: 13 }) {
      CenteredTextBadge({
        badgeText: student.name.length > 0 ? student.name.substring(0, 1) : '伴',
        badgeWidth: 40,
        badgeHeight: 40,
        badgeFontSize: 15,
        badgeRadius: 12,
        badgeForeground: AppTheme.PRIMARY,
        badgeBackground: AppTheme.PRIMARY_SOFT
      });
      Column({ space: 3 }) {
        Text(student.name)
          .width('100%')
          .fontSize(AppTheme.CARD_TITLE_SIZE)
          .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
          .fontColor(AppTheme.TEXT);
        Text(`${student.grade} · ${student.className}`)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(2);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ top: 12, bottom: 12 })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${student.name}，${student.grade}，${student.className}`)
    .onClick(() => this.onSelectStudent(student.id));
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        this.BrandHeader();

        Text('家长')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ left: 4 });
        Column() {
          this.ParentRow();
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);

        Text('孩子')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT)
          .margin({ left: 4, top: 8 });
        Column() {
          ForEach(this.students(), (student: StudentProfile, index: number) => {
            this.StudentRow(student);
            if (index < this.students().length - 1) {
              Divider().color(AppTheme.DIVIDER);
            }
          }, (student: StudentProfile) => student.id);
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);

      }
      .width('100%')
      .constraintSize({ maxWidth: 560 })
      .padding({ left: AppTheme.PAGE_PADDING_COMPACT, right: AppTheme.PAGE_PADDING_COMPACT, top: 48, bottom: 40 });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
