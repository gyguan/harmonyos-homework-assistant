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
