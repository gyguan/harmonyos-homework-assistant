import { AppTheme } from '../../common/theme/AppTheme';

@Component
export struct SegmentedSelectionButton {
  @Prop label: string;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Normal })
      .height(AppTheme.MIN_TOUCH_TARGET)
      .padding({ left: 13, right: 13 })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.TEXT)
      .accessibilityText(this.selected ? `${this.label}，已选择` : this.label)
      .onClick(() => this.onSelect());
  }
}

@Component
export struct FilterSummaryEntry {
  @Prop label: string;
  @Prop value: string;
  @Prop active: boolean = false;
  onOpen: () => void = () => {};

  build() {
    Column({ space: 3 }) {
      Text(this.label).fontSize(11).fontColor(AppTheme.TERTIARY_TEXT);
      Row({ space: 3 }) {
        Text(this.value)
          .fontSize(13)
          .fontWeight(this.active ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.active ? AppTheme.PRIMARY : AppTheme.TEXT);
        Text('⌄').fontSize(11).fontColor(this.active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      }
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${this.label}：${this.value}，打开筛选`)
    .onClick(() => this.onOpen());
  }
}

@Component
export struct StatusSelectionChip {
  @Prop label: string;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Text(this.label)
      .fontSize(12)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.TEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 13, right: 13, top: 8, bottom: 8 })
      .backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE)
      .border({ width: 1, color: this.selected ? AppTheme.PRIMARY : AppTheme.BORDER })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.selected ? `${this.label}，已选择` : this.label)
      .onClick(() => this.onSelect());
  }
}

@Component
export struct SettingsToggleRow {
  @Prop title: string;
  @Prop description: string;
  @Prop enabled: boolean = false;
  onToggle: (enabled: boolean) => void = (_enabled: boolean) => {};

  build() {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(this.title).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(this.description).width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Toggle({ type: ToggleType.Switch, isOn: this.enabled })
        .accessibilityText(this.enabled ? `${this.title}，已开启` : `${this.title}，已关闭`)
        .onChange((value: boolean) => this.onToggle(value));
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 });
  }
}

@Component
export struct ReadonlySettingStateRow {
  @Prop title: string;
  @Prop description: string;
  @Prop enabled: boolean = false;

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.description)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(this.enabled ? '已开启' : '已关闭')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.enabled ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 });
  }
}
