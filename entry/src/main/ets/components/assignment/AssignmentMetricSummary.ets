import { AppTheme } from '../../common/theme/AppTheme';

export enum AssignmentMetricKey {
  ALL = 'ALL',
  PENDING = 'PENDING',
  SUBMITTED = 'SUBMITTED',
  COMPLETED = 'COMPLETED'
}

@Component
export struct AssignmentMetricSummary {
  @Prop allCount: number = 0;
  @Prop pendingCount: number = 0;
  @Prop submittedCount: number = 0;
  @Prop completedCount: number = 0;
  @Prop selectedKey: AssignmentMetricKey = AssignmentMetricKey.ALL;
  @Prop interactive: boolean = false;
  onSelect: (key: AssignmentMetricKey) => void = (_key: AssignmentMetricKey) => {};

  @Builder
  private Metric(label: string, value: number, key: AssignmentMetricKey, tone: string) {
    Column({ space: 5 }) {
      Text(`${value}`)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(tone === 'pending' ? AppTheme.WARNING :
          tone === 'done' ? AppTheme.SUCCESS : AppTheme.PRIMARY);
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 76 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(tone === 'pending' ? AppTheme.WARNING_SOFT :
      tone === 'done' ? AppTheme.SUCCESS_SOFT :
        key === AssignmentMetricKey.SUBMITTED ? AppTheme.PRIMARY_SOFT : AppTheme.PRIMARY_FAINT)
    .border({
      width: this.interactive && this.selectedKey === key ? 2 : 0,
      color: this.interactive && this.selectedKey === key ?
        (tone === 'pending' ? AppTheme.WARNING :
          tone === 'done' ? AppTheme.SUCCESS : AppTheme.PRIMARY) : AppTheme.BORDER
    })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityText(this.interactive ? `${label} ${value} 项，点击筛选` : `${label} ${value} 项`)
    .onClick(() => {
      if (this.interactive) this.onSelect(key);
    });
  }

  build() {
    Row({ space: 8 }) {
      this.Metric('全部任务', this.allCount, AssignmentMetricKey.ALL, 'all');
      this.Metric('待完成', this.pendingCount, AssignmentMetricKey.PENDING, 'pending');
      this.Metric('待验收', this.submittedCount, AssignmentMetricKey.SUBMITTED, 'submitted');
      this.Metric('已完成', this.completedCount, AssignmentMetricKey.COMPLETED, 'done');
    }
    .width('100%');
  }
}
