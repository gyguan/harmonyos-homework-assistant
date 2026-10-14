import { AppTheme } from '../../common/theme/AppTheme';
import { ChoiceSelectionChip } from '../selection/SelectionControls';

export class HomeworkCoverageSubject {
  static readonly ALL: string = 'ALL';
  static readonly CHINESE: string = 'CHINESE';
  static readonly MATH: string = 'MATH';
  static readonly ENGLISH: string = 'ENGLISH';

  static label(value: string): string {
    if (value === HomeworkCoverageSubject.ALL) return '全部';
    if (value === HomeworkCoverageSubject.CHINESE) return '语文';
    if (value === HomeworkCoverageSubject.MATH) return '数学';
    if (value === HomeworkCoverageSubject.ENGLISH) return '英语';
    return value;
  }

  static labels(values: string[]): string {
    if (HomeworkCoverageSubject.contains(values, HomeworkCoverageSubject.ALL)) return '全部作业';
    let labels: string[] = [];
    for (let value of values) labels.push(HomeworkCoverageSubject.label(value));
    return labels.join('、');
  }

  /** 单行摘要文案，供底栏折叠态使用；空选择统一显示"未标记"。 */
  static summary(values: string[]): string {
    if (values.length === 0) return '未标记';
    let text = HomeworkCoverageSubject.labels(values);
    return text.length > 0 ? text : '未标记';
  }

  static contains(values: string[], target: string): boolean {
    for (let value of values) if (value === target) return true;
    return false;
  }

  static toggle(values: string[], subject: string): string[] {
    if (subject === HomeworkCoverageSubject.ALL) {
      return HomeworkCoverageSubject.contains(values, HomeworkCoverageSubject.ALL) ? [] :
        [HomeworkCoverageSubject.ALL];
    }
    let next: string[] = [];
    for (let value of values) {
      if (value !== HomeworkCoverageSubject.ALL && value !== subject) next.push(value);
    }
    if (!HomeworkCoverageSubject.contains(values, subject)) next.push(subject);
    return HomeworkCoverageSubject.order(next);
  }

  static order(values: string[]): string[] {
    let result: string[] = [];
    for (let subject of [
      HomeworkCoverageSubject.CHINESE,
      HomeworkCoverageSubject.MATH,
      HomeworkCoverageSubject.ENGLISH
    ]) {
      if (HomeworkCoverageSubject.contains(values, subject)) result.push(subject);
    }
    return result;
  }
}

@Component
export struct HomeworkCoveragePicker {
  @Prop selected: string[] = [];
  @Prop disabled: boolean = false;
  @Prop title: string = '同步给其他家长';
  @Prop description: string = '选择你已经负责布置完成的今日作业';
  onChange: (subjects: string[]) => void = (_subjects: string[]) => {};

  @Builder
  private CoverageChip(subject: string) {
    ChoiceSelectionChip({
      label: HomeworkCoverageSubject.label(subject),
      selected: HomeworkCoverageSubject.contains(this.selected, subject),
      onSelect: () => {
        if (!this.disabled) this.onChange(HomeworkCoverageSubject.toggle(this.selected, subject));
      }
    });
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(this.description)
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      Flex({ wrap: FlexWrap.Wrap }) {
        Row() { this.CoverageChip(HomeworkCoverageSubject.ALL); }
          .margin({ right: 8, bottom: 8 });
        Row() { this.CoverageChip(HomeworkCoverageSubject.CHINESE); }
          .margin({ right: 8, bottom: 8 });
        Row() { this.CoverageChip(HomeworkCoverageSubject.MATH); }
          .margin({ right: 8, bottom: 8 });
        Row() { this.CoverageChip(HomeworkCoverageSubject.ENGLISH); }
          .margin({ right: 8, bottom: 8 });
      }
      .width('100%')
      .enabled(!this.disabled);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}

/**
 * 底栏折叠态入口：只用一行展示"同步给其他家长"的当前状态，点按后打开完整选择面板。
 * 避免可选项（协同标记）在"确认并发布"这一强任务路径上长期占用大块空间。
 */
@Component
export struct HomeworkCoverageSummaryRow {
  @Prop selected: string[] = [];
  @Prop disabled: boolean = false;
  @Prop label: string = '同步给其他家长';
  onOpen: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Text(this.label)
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(1);
      Text(HomeworkCoverageSubject.summary(this.selected))
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(this.selected.length > 0 ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.selected.length > 0 ? '修改' : '设置')
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY)
        .maxLines(1);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .padding({ left: 12, right: 12 })
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .enabled(!this.disabled)
    .opacity(this.disabled ? 0.6 : 1)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${this.label}：${HomeworkCoverageSubject.summary(this.selected)}，点击选择`)
    .onClick(() => {
      if (!this.disabled) this.onOpen();
    });
  }
}
