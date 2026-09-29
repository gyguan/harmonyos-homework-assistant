import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import {
  ScheduledAssignmentDuePolicy,
  ScheduledAssignmentPlan,
  ScheduledAssignmentPlanDraft,
  ScheduledAssignmentPlanType,
  ScheduledAssignmentRun,
  ScheduledAssignmentScheduleType,
  ScheduledAssignmentTemplate
} from '../../../domain/model/ScheduledAssignmentModels';
import { ParentScheduledAssignmentViewModel } from './ParentScheduledAssignmentViewModel';

@Component
export struct ParentScheduledAssignmentPage {
  @State private plans: ScheduledAssignmentPlan[] = [];
  @State private recentRuns: ScheduledAssignmentRun[] = [];
  @State private loading: boolean = false;
  @State private busy: boolean = false;
  @State private message: string = '';
  @State private messageError: boolean = false;
  @State private showEditor: boolean = false;
  @State private editingId: string = '';

  @State private planType: string = ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT;
  @State private name: string = '';
  @State private scheduleType: string = ScheduledAssignmentScheduleType.WEEKDAYS;
  @State private timeOfDay: string = '17:00';
  @State private weekdaysCsv: string = 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY';
  @State private startDate: string = '';
  @State private endDate: string = '';

  @State private subjectCode: string = 'CHINESE';
  @State private taskTitle: string = '';
  @State private instruction: string = '';
  @State private expectedMinutesText: string = '20';
  @State private duePolicy: string = ScheduledAssignmentDuePolicy.SAME_DAY_AT;
  @State private dueTime: string = '21:00';
  @State private dueOffsetMinutesText: string = '120';

  onBack: () => void = () => {};
  private readonly viewModel: ParentScheduledAssignmentViewModel =
    new ParentScheduledAssignmentViewModel();

  aboutToAppear(): void {
    if (this.startDate.length === 0) this.startDate = this.shanghaiToday();
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    try {
      this.plans = await this.viewModel.list();
    } catch (error) {
      this.showFeedback(error instanceof Error ? error.message : '读取定时作业失败', true);
    } finally {
      this.loading = false;
    }
  }

  private resetEditorState(): void {
    this.editingId = '';
    this.planType = ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT;
    this.name = '';
    this.scheduleType = ScheduledAssignmentScheduleType.WEEKDAYS;
    this.timeOfDay = '17:00';
    this.weekdaysCsv = 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY';
    this.startDate = this.shanghaiToday();
    this.endDate = '';
    this.subjectCode = 'CHINESE';
    this.taskTitle = '';
    this.instruction = '';
    this.expectedMinutesText = '20';
    this.duePolicy = ScheduledAssignmentDuePolicy.SAME_DAY_AT;
    this.dueTime = '21:00';
    this.dueOffsetMinutesText = '120';
    this.recentRuns = [];
    this.message = '';
    this.messageError = false;
  }

  private openCreate(): void {
    this.resetEditorState();
    this.showEditor = true;
  }

  private async openEdit(plan: ScheduledAssignmentPlan): Promise<void> {
    this.resetEditorState();
    this.editingId = plan.id;
    this.planType = plan.planType;
    this.name = plan.name;
    this.scheduleType = plan.scheduleType;
    this.timeOfDay = plan.timeOfDay;
    this.weekdaysCsv = plan.weekdays.join(',');
    this.startDate = plan.startDate;
    this.endDate = plan.endDate;
    if (plan.template !== null) {
      this.subjectCode = plan.template.subjectCode;
      this.taskTitle = plan.template.title;
      this.instruction = plan.template.instruction;
      this.expectedMinutesText = String(plan.template.expectedMinutes);
      this.duePolicy = plan.template.duePolicy;
      this.dueTime = plan.template.dueTime.length > 0 ? plan.template.dueTime : '21:00';
      this.dueOffsetMinutesText = plan.template.dueOffsetMinutes > 0 ?
        String(plan.template.dueOffsetMinutes) : '120';
    }
    this.showEditor = true;
    try {
      this.recentRuns = await this.viewModel.runs(plan);
    } catch {
      this.recentRuns = [];
    }
  }

  private closeEditor(): void {
    if (this.busy) return;
    this.showEditor = false;
    this.editingId = '';
    this.recentRuns = [];
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    let draft = this.buildDraft();
    if (draft === null) return;
    this.busy = true;
    this.message = '';
    try {
      if (this.editingId.length === 0) {
        await this.viewModel.create(draft);
        this.showFeedback('定时计划已创建', false);
      } else {
        let current = this.findPlan(this.editingId);
        if (current === null) throw new Error('计划已不存在，请刷新');
        await this.viewModel.update(current, draft);
        this.showFeedback('定时计划已更新', false);
      }
      this.showEditor = false;
      this.editingId = '';
      this.recentRuns = [];
      await this.refresh();
    } catch (error) {
      this.showFeedback(error instanceof Error ? error.message : '保存定时计划失败', true);
    } finally {
      this.busy = false;
    }
  }

  private async toggle(plan: ScheduledAssignmentPlan): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.viewModel.toggle(plan);
      await this.refresh();
    } catch (error) {
      this.showFeedback(error instanceof Error ? error.message : '更新计划状态失败', true);
    } finally {
      this.busy = false;
    }
  }

  private async remove(plan: ScheduledAssignmentPlan): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.viewModel.delete(plan);
      this.showFeedback('计划已删除，已创建的作业不会受影响', false);
      await this.refresh();
    } catch (error) {
      this.showFeedback(error instanceof Error ? error.message : '删除定时计划失败', true);
    } finally {
      this.busy = false;
    }
  }

  private buildDraft(): ScheduledAssignmentPlanDraft | null {
    let planName = this.name.trim();
    if (planName.length === 0) {
      this.showFeedback('请填写计划名称', true);
      return null;
    }
    if (!this.validTime(this.timeOfDay)) {
      this.showFeedback('创建时间格式应为 HH:mm，例如 17:00', true);
      return null;
    }
    if (!this.validDate(this.startDate)) {
      this.showFeedback('开始日期格式应为 YYYY-MM-DD', true);
      return null;
    }
    if (this.endDate.trim().length > 0 && !this.validDate(this.endDate)) {
      this.showFeedback('结束日期格式应为 YYYY-MM-DD', true);
      return null;
    }

    let weekdays = this.weekdayValues();
    if (this.scheduleType === ScheduledAssignmentScheduleType.WEEKLY && weekdays.length === 0) {
      this.showFeedback('每周计划至少选择一天', true);
      return null;
    }

    let template: ScheduledAssignmentTemplate | null = null;
    if (this.planType === ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT) {
      let title = this.taskTitle.trim();
      let requirement = this.instruction.trim();
      let expectedMinutes = Number(this.expectedMinutesText.trim());
      if (title.length === 0 || requirement.length === 0) {
        this.showFeedback('请填写任务名称和完成要求', true);
        return null;
      }
      if (!Number.isFinite(expectedMinutes) || expectedMinutes < 1 || expectedMinutes > 240 ||
        Math.floor(expectedMinutes) !== expectedMinutes) {
        this.showFeedback('预计用时请输入 1～240 分钟的整数', true);
        return null;
      }

      let dueOffset = 0;
      if (this.duePolicy === ScheduledAssignmentDuePolicy.SAME_DAY_AT ||
        this.duePolicy === ScheduledAssignmentDuePolicy.NEXT_DAY_AT) {
        if (!this.validTime(this.dueTime)) {
          this.showFeedback('截止时间格式应为 HH:mm', true);
          return null;
        }
      } else if (this.duePolicy === ScheduledAssignmentDuePolicy.AFTER_MINUTES) {
        dueOffset = Number(this.dueOffsetMinutesText.trim());
        if (!Number.isFinite(dueOffset) || dueOffset < 1 || dueOffset > 10080 ||
          Math.floor(dueOffset) !== dueOffset) {
          this.showFeedback('创建后截止分钟数请输入 1～10080 的整数', true);
          return null;
        }
      }

      template = {
        assignmentType: 'EXTRA',
        subject: this.subjectDisplay(this.subjectCode),
        subjectCode: this.subjectCode,
        title: title,
        instruction: requirement,
        expectedMinutes: expectedMinutes,
        duePolicy: this.duePolicy,
        dueTime: this.dueTime,
        dueOffsetMinutes: dueOffset
      };
    }

    return {
      planType: this.planType,
      name: planName,
      scheduleType: this.scheduleType,
      timeOfDay: this.timeOfDay.trim(),
      weekdays: weekdays,
      startDate: this.startDate.trim(),
      endDate: this.endDate.trim(),
      template: template
    };
  }

  private selectOption(kind: string, value: string): void {
    if (kind === 'PLAN_TYPE') this.planType = value;
    else if (kind === 'SCHEDULE') this.scheduleType = value;
    else if (kind === 'SUBJECT') this.subjectCode = value;
    else if (kind === 'DUE') this.duePolicy = value;
    else if (kind === 'WEEKDAY') this.toggleWeekday(value);
  }

  private findPlan(id: string): ScheduledAssignmentPlan | null {
    for (let plan of this.plans) if (plan.id === id) return plan;
    return null;
  }

  private showFeedback(value: string, error: boolean): void {
    this.message = value;
    this.messageError = error;
  }

  private weekdayValues(): string[] {
    let result: string[] = [];
    for (let value of this.weekdaysCsv.split(',')) {
      let normalized = value.trim();
      if (normalized.length > 0) result.push(normalized);
    }
    return result;
  }

  private hasWeekday(value: string): boolean {
    for (let item of this.weekdayValues()) if (item === value) return true;
    return false;
  }

  private toggleWeekday(value: string): void {
    let values = this.weekdayValues();
    let next: string[] = [];
    let found = false;
    for (let item of values) {
      if (item === value) found = true;
      else next.push(item);
    }
    if (!found) next.push(value);
    this.weekdaysCsv = next.join(',');
  }

  private validTime(value: string): boolean {
    return /^([01]\d|2[0-3]):[0-5]\d$/.test(value.trim());
  }

  private validDate(value: string): boolean {
    return /^\d{4}-\d{2}-\d{2}$/.test(value.trim());
  }

  private twoDigits(value: number): string {
    return value < 10 ? '0' + String(value) : String(value);
  }

  private shanghaiToday(): string {
    let value = new Date(Date.now() + 8 * 60 * 60 * 1000);
    return String(value.getUTCFullYear()) + '-' +
      this.twoDigits(value.getUTCMonth() + 1) + '-' + this.twoDigits(value.getUTCDate());
  }

  private formatEpoch(epochMs: number): string {
    if (epochMs <= 0) return '—';
    let value = new Date(epochMs + 8 * 60 * 60 * 1000);
    return this.twoDigits(value.getUTCMonth() + 1) + '-' + this.twoDigits(value.getUTCDate()) + ' ' +
      this.twoDigits(value.getUTCHours()) + ':' + this.twoDigits(value.getUTCMinutes());
  }

  private scheduleLabel(plan: ScheduledAssignmentPlan): string {
    if (plan.scheduleType === ScheduledAssignmentScheduleType.ONCE) {
      return '仅一次 ' + plan.startDate + ' ' + plan.timeOfDay;
    }
    if (plan.scheduleType === ScheduledAssignmentScheduleType.DAILY) return '每天 ' + plan.timeOfDay;
    if (plan.scheduleType === ScheduledAssignmentScheduleType.WEEKDAYS) return '工作日 ' + plan.timeOfDay;
    return '每周 ' + this.weekdayLabels(plan.weekdays) + ' ' + plan.timeOfDay;
  }

  private weekdayLabels(values: string[]): string {
    let result: string[] = [];
    for (let value of values) result.push(this.weekdayLabel(value));
    return result.join('、');
  }

  private weekdayLabel(value: string): string {
    if (value === 'MONDAY') return '一';
    if (value === 'TUESDAY') return '二';
    if (value === 'WEDNESDAY') return '三';
    if (value === 'THURSDAY') return '四';
    if (value === 'FRIDAY') return '五';
    if (value === 'SATURDAY') return '六';
    return '日';
  }

  private subjectDisplay(code: string): string {
    if (code === 'CHINESE') return '语文';
    if (code === 'MATH') return '数学';
    if (code === 'ENGLISH') return '英语';
    return '其他';
  }

  @Builder
  private PlanCard(plan: ScheduledAssignmentPlan) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(plan.name)
            .width('100%')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(plan.planType === ScheduledAssignmentPlanType.VOICE_MATERIAL_AUTO ?
            '自动语音作业' : '普通定时作业')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(plan.status === 'ENABLED' ? '已开启' : plan.status === 'PAUSED' ? '已暂停' : '已结束')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(plan.status === 'ENABLED' ? AppTheme.SUCCESS : AppTheme.SUBTEXT)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(plan.status === 'ENABLED' ? AppTheme.SUCCESS_SOFT : AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Text(this.scheduleLabel(plan))
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.TEXT);
      Text('下次执行：' + this.formatEpoch(plan.nextFireAtEpochMs))
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .fontColor(AppTheme.SUBTEXT);

      Row({ space: 8 }) {
        Button('编辑', { type: ButtonType.Normal })
          .height(AppTheme.MIN_TOUCH_TARGET)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => { void this.openEdit(plan); });
        if (plan.status !== 'ENDED') {
          Button(plan.status === 'ENABLED' ? '暂停' : '恢复', { type: ButtonType.Normal })
            .height(AppTheme.MIN_TOUCH_TARGET)
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(() => { void this.toggle(plan); });
        }
        Blank();
        Button('删除', { type: ButtonType.Normal })
          .height(AppTheme.MIN_TOUCH_TARGET)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .backgroundColor(AppTheme.DANGER_SOFT)
          .fontColor(AppTheme.DANGER)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => { void this.remove(plan); });
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private WeekdayOptions() {
    Row({ space: 5 }) {
      SegmentedSelectionButton({ label: '一', selected: this.hasWeekday('MONDAY'), onSelect: () => this.selectOption('WEEKDAY', 'MONDAY') });
      SegmentedSelectionButton({ label: '二', selected: this.hasWeekday('TUESDAY'), onSelect: () => this.selectOption('WEEKDAY', 'TUESDAY') });
      SegmentedSelectionButton({ label: '三', selected: this.hasWeekday('WEDNESDAY'), onSelect: () => this.selectOption('WEEKDAY', 'WEDNESDAY') });
      SegmentedSelectionButton({ label: '四', selected: this.hasWeekday('THURSDAY'), onSelect: () => this.selectOption('WEEKDAY', 'THURSDAY') });
      SegmentedSelectionButton({ label: '五', selected: this.hasWeekday('FRIDAY'), onSelect: () => this.selectOption('WEEKDAY', 'FRIDAY') });
      SegmentedSelectionButton({ label: '六', selected: this.hasWeekday('SATURDAY'), onSelect: () => this.selectOption('WEEKDAY', 'SATURDAY') });
      SegmentedSelectionButton({ label: '日', selected: this.hasWeekday('SUNDAY'), onSelect: () => this.selectOption('WEEKDAY', 'SUNDAY') });
    }
    .width('100%');
  }

  @Builder
  private Editor() {
    Column({ space: 16 }) {
      Row() {
        Text(this.editingId.length === 0 ? '新建定时计划' : '编辑定时计划')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        Button('取消', { type: ButtonType.Normal })
          .height(AppTheme.MIN_TOUCH_TARGET)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onClick(() => this.closeEditor());
      }
      .width('100%');

      Text('任务类型')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({ label: '普通作业', selected: this.planType === ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT, onSelect: () => this.selectOption('PLAN_TYPE', ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT) });
        SegmentedSelectionButton({ label: '自动语音作业', selected: this.planType === ScheduledAssignmentPlanType.VOICE_MATERIAL_AUTO, onSelect: () => this.selectOption('PLAN_TYPE', ScheduledAssignmentPlanType.VOICE_MATERIAL_AUTO) });
      }
      .width('100%');

      Row() {
        Text('计划名称')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        Blank();
        if (this.name.length > 0) {
          Text('清空')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 4 })
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('清空计划名称')
            .onClick(() => this.name = '');
        }
      }
      .width('100%');

      TextInput({ placeholder: '例如：每天阅读 20 分钟', text: this.name })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .fontSize(AppTheme.FORM_TEXT_SIZE)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.name = value);

      Text('重复方式')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 5 }) {
        SegmentedSelectionButton({ label: '仅一次', selected: this.scheduleType === ScheduledAssignmentScheduleType.ONCE, onSelect: () => this.selectOption('SCHEDULE', ScheduledAssignmentScheduleType.ONCE) });
        SegmentedSelectionButton({ label: '每天', selected: this.scheduleType === ScheduledAssignmentScheduleType.DAILY, onSelect: () => this.selectOption('SCHEDULE', ScheduledAssignmentScheduleType.DAILY) });
        SegmentedSelectionButton({ label: '工作日', selected: this.scheduleType === ScheduledAssignmentScheduleType.WEEKDAYS, onSelect: () => this.selectOption('SCHEDULE', ScheduledAssignmentScheduleType.WEEKDAYS) });
        SegmentedSelectionButton({ label: '自定义', selected: this.scheduleType === ScheduledAssignmentScheduleType.WEEKLY, onSelect: () => this.selectOption('SCHEDULE', ScheduledAssignmentScheduleType.WEEKLY) });
      }
      .width('100%');
      if (this.scheduleType === ScheduledAssignmentScheduleType.WEEKLY) {
        this.WeekdayOptions();
      }

      Row({ space: 10 }) {
        Column({ space: 5 }) {
          Text('创建时间')
            .width('100%')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          TextInput({ placeholder: '17:00', text: this.timeOfDay })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.timeOfDay = value);
        }
        .layoutWeight(1);

        Column({ space: 5 }) {
          Text('开始日期')
            .width('100%')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          TextInput({ placeholder: 'YYYY-MM-DD', text: this.startDate })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.startDate = value);
        }
        .layoutWeight(1);
      }
      .width('100%');

      if (this.scheduleType !== ScheduledAssignmentScheduleType.ONCE) {
        TextInput({ placeholder: '结束日期（可不填，YYYY-MM-DD）', text: this.endDate })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.endDate = value);
      }

      if (this.planType === ScheduledAssignmentPlanType.MANUAL_ASSIGNMENT) {
        Text('作业模板')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Row({ space: 6 }) {
          SegmentedSelectionButton({ label: '语文', selected: this.subjectCode === 'CHINESE', onSelect: () => this.selectOption('SUBJECT', 'CHINESE') });
          SegmentedSelectionButton({ label: '数学', selected: this.subjectCode === 'MATH', onSelect: () => this.selectOption('SUBJECT', 'MATH') });
          SegmentedSelectionButton({ label: '英语', selected: this.subjectCode === 'ENGLISH', onSelect: () => this.selectOption('SUBJECT', 'ENGLISH') });
          SegmentedSelectionButton({ label: '其他', selected: this.subjectCode === 'OTHER', onSelect: () => this.selectOption('SUBJECT', 'OTHER') });
        }
        .width('100%');

        Row() {
          Text('任务名称')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.taskTitle.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 4 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空任务名称')
              .onClick(() => this.taskTitle = '');
          }
        }
        .width('100%');

        TextInput({ placeholder: '任务名称', text: this.taskTitle })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.taskTitle = value);

        Row() {
          Text('完成要求')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.instruction.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 4 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空完成要求')
              .onClick(() => this.instruction = '');
          }
        }
        .width('100%');

        TextArea({ placeholder: '完成要求', text: this.instruction })
          .width('100%')
          .height(104)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.instruction = value);

        TextInput({ placeholder: '预计用时（分钟）', text: this.expectedMinutesText })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.expectedMinutesText = value);

        Text('截止规则')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        Row({ space: 5 }) {
          SegmentedSelectionButton({ label: '当天', selected: this.duePolicy === ScheduledAssignmentDuePolicy.SAME_DAY_AT, onSelect: () => this.selectOption('DUE', ScheduledAssignmentDuePolicy.SAME_DAY_AT) });
          SegmentedSelectionButton({ label: '次日', selected: this.duePolicy === ScheduledAssignmentDuePolicy.NEXT_DAY_AT, onSelect: () => this.selectOption('DUE', ScheduledAssignmentDuePolicy.NEXT_DAY_AT) });
          SegmentedSelectionButton({ label: '创建后', selected: this.duePolicy === ScheduledAssignmentDuePolicy.AFTER_MINUTES, onSelect: () => this.selectOption('DUE', ScheduledAssignmentDuePolicy.AFTER_MINUTES) });
          SegmentedSelectionButton({ label: '不设置', selected: this.duePolicy === ScheduledAssignmentDuePolicy.NONE, onSelect: () => this.selectOption('DUE', ScheduledAssignmentDuePolicy.NONE) });
        }
        .width('100%');

        if (this.duePolicy === ScheduledAssignmentDuePolicy.SAME_DAY_AT ||
          this.duePolicy === ScheduledAssignmentDuePolicy.NEXT_DAY_AT) {
          TextInput({ placeholder: '截止时间 HH:mm', text: this.dueTime })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.dueTime = value);
        } else if (this.duePolicy === ScheduledAssignmentDuePolicy.AFTER_MINUTES) {
          TextInput({ placeholder: '创建后多少分钟截止', text: this.dueOffsetMinutesText })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.dueOffsetMinutesText = value);
        }
      } else {
        Text('到点后自动从语音素材库选择任务；存在未完成语音任务或当天已自动创建时不会重复创建。')
          .width('100%')
          .fontSize(AppTheme.BODY_SIZE)
          .lineHeight(AppTheme.BODY_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .padding(12)
          .backgroundColor(AppTheme.PRIMARY_FAINT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      }

      if (this.editingId.length > 0 && this.recentRuns.length > 0) {
        Text('最近执行')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        ForEach(this.recentRuns, (run: ScheduledAssignmentRun) => {
          Row({ space: 8 }) {
            Text(this.formatEpoch(run.scheduledFireAtEpochMs))
              .fontSize(AppTheme.META_SIZE)
              .fontColor(AppTheme.TEXT);
            Text(run.status === 'SUCCESS' ? '成功' : run.status === 'SKIPPED' ? '跳过' : '失败')
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontColor(run.status === 'SUCCESS' ? AppTheme.SUCCESS :
                run.status === 'FAILED' ? AppTheme.DANGER : AppTheme.SUBTEXT);
            Blank();
            if (run.skipReason.length > 0) {
              Text(run.skipReason)
                .fontSize(AppTheme.CAPTION_SIZE)
                .fontColor(AppTheme.SUBTEXT);
            }
          }
          .width('100%');
        }, (run: ScheduledAssignmentRun) => run.id);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_STANDARD)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_STANDARD);
  }

  @Builder
  private EditorFooter() {
    Column() {
      Button(this.busy ? '正在保存…' : '保存计划', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .enabled(!this.busy)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onClick(() => { void this.save(); });
    }
    .width('100%')
    .padding({ top: 10, bottom: 14 })
    .backgroundColor(AppTheme.BACKGROUND);
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '定时作业',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: 12 }) {
            Row() {
              Column({ space: 3 }) {
                Text('当前孩子：' + this.viewModel.studentName())
                  .fontSize(AppTheme.BODY_SIZE)
                  .fontColor(AppTheme.TEXT);
                Text('所有计划按 Asia/Shanghai 时间执行')
                  .fontSize(AppTheme.CAPTION_SIZE)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .alignItems(HorizontalAlign.Start);
              Blank();
              if (!this.showEditor) {
                Button('＋ 新建', { type: ButtonType.Normal })
                  .height(AppTheme.MIN_TOUCH_TARGET)
                  .fontSize(AppTheme.ACTION_TEXT_SIZE)
                  .backgroundColor(AppTheme.PRIMARY)
                  .fontColor(AppTheme.TEXT_ON_PRIMARY)
                  .borderRadius(AppTheme.CONTROL_RADIUS)
                  .onClick(() => this.openCreate());
              }
            }
            .width('100%');

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(AppTheme.META_SIZE)
                .lineHeight(AppTheme.META_LINE_HEIGHT)
                .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS)
                .padding(12)
                .backgroundColor(this.messageError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            if (this.showEditor) {
              this.Editor();
            } else if (this.loading) {
              Text('正在读取定时计划…')
                .width('100%')
                .fontSize(AppTheme.BODY_SIZE)
                .fontColor(AppTheme.SUBTEXT)
                .padding(20);
            } else if (this.plans.length === 0) {
              Column({ space: 8 }) {
                Text('还没有定时作业')
                  .fontSize(AppTheme.SECTION_TITLE_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text('可以按固定时间自动创建普通作业，或从语音素材库自动创建语音任务。')
                  .fontSize(AppTheme.BODY_SIZE)
                  .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                  .fontColor(AppTheme.SUBTEXT)
                  .textAlign(TextAlign.Center);
              }
              .width('100%')
              .padding(28)
              .backgroundColor(AppTheme.CARD_SURFACE)
              .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
            } else {
              ForEach(this.plans, (plan: ScheduledAssignmentPlan) => {
                this.PlanCard(plan);
              }, (plan: ScheduledAssignmentPlan) => plan.id);
            }

            if (!this.showEditor) {
              Text('暂停或删除计划只影响未来创建，不会删除已经生成的作业。')
                .width('100%')
                .fontSize(AppTheme.CAPTION_SIZE)
                .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                .fontColor(AppTheme.SUBTEXT)
                .padding({ top: 4, bottom: 8 });
            }
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);

        if (this.showEditor) {
          this.EditorFooter();
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
