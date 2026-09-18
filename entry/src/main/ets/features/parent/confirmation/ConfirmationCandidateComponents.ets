import { AppTheme } from '../../../common/theme/AppTheme';
import { ChoiceSelectionChip } from '../../../components/selection/SelectionControls';
import { CandidateAssignment, Subject } from '../../../domain/model/HomeworkModels';

@Component
export struct ConfirmationCandidateCard {
  @Prop item: CandidateAssignment;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Row({ space: 7 }) {
          Text(this.item.subject)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          if (this.item.confidence < 0.8) {
            Text('重点确认')
              .fontSize(10)
              .fontColor(AppTheme.WARNING)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(AppTheme.WARNING_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
          }
        }
        Blank();
        Text(this.item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Text(this.item.title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(2);

      Text(`预计 ${this.item.expectedMinutes} 分钟 · ${this.item.textbookRef.length > 0 ?
        this.item.textbookRef : '未设置教材页码'}`)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT)
        .maxLines(1);

      Text(`来源证据 · ${this.item.sourceEvidence.excerpt}`)
        .width('100%')
        .fontSize(11)
        .lineHeight(17)
        .fontColor(this.item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.TERTIARY_TEXT)
        .maxLines(2);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.selected ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({ width: this.selected ? 1 : 0,
      color: this.selected ? AppTheme.PRIMARY : Color.Transparent })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.selected ?
      `${this.item.subject}，${this.item.title}，当前编辑` :
      `${this.item.subject}，${this.item.title}，打开编辑`)
    .onClick(() => this.onSelect());
  }
}

@Component
export struct ConfirmationCandidateEditor {
  @Prop item: CandidateAssignment;
  onDelete: (candidateId: string) => void = (_candidateId: string) => {};
  onSubjectChange: (candidate: CandidateAssignment, subject: Subject) => void =
    (_candidate: CandidateAssignment, _subject: Subject) => {};
  onTitleChange: (candidate: CandidateAssignment, value: string) => void =
    (_candidate: CandidateAssignment, _value: string) => {};
  onInstructionChange: (candidate: CandidateAssignment, value: string) => void =
    (_candidate: CandidateAssignment, _value: string) => {};
  onDueTextChange: (candidate: CandidateAssignment, value: string) => void =
    (_candidate: CandidateAssignment, _value: string) => {};
  onMinutesChange: (candidate: CandidateAssignment, minutes: number) => void =
    (_candidate: CandidateAssignment, _minutes: number) => {};
  onTextbookRefChange: (candidate: CandidateAssignment, value: string) => void =
    (_candidate: CandidateAssignment, _value: string) => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text(this.item.confidence < 0.8 ? '重点确认' : '核对作业')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(this.item.confidence < 0.8 ?
            '识别置信度较低，请对照老师原文逐项核对。' : '发布前确认任务内容与时间。')
            .fontSize(12)
            .fontColor(this.item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('删除')
          .fontSize(13)
          .fontColor(AppTheme.DANGER)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(`删除${this.item.title}`)
          .onClick(() => this.onDelete(this.item.id));
      }
      .width('100%');

      Row({ space: 8 }) {
        ChoiceSelectionChip({
          label: Subject.CHINESE,
          selected: this.item.subject === Subject.CHINESE,
          onSelect: () => this.onSubjectChange(this.item, Subject.CHINESE)
        });
        ChoiceSelectionChip({
          label: Subject.MATH,
          selected: this.item.subject === Subject.MATH,
          onSelect: () => this.onSubjectChange(this.item, Subject.MATH)
        });
        ChoiceSelectionChip({
          label: Subject.ENGLISH,
          selected: this.item.subject === Subject.ENGLISH,
          onSelect: () => this.onSubjectChange(this.item, Subject.ENGLISH)
        });
      }
      .width('100%');

      Text('作业标题').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.item.title })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onTitleChange(this.item, value));

      Text('老师要求').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextArea({ text: this.item.instruction })
        .width('100%')
        .height(92)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onInstructionChange(this.item, value));

      Text('截止时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.item.dueText })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onDueTextChange(this.item, value));

      Text('预计用时（分钟）').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      Row({ space: 6 }) {
        ChoiceSelectionChip({
          label: '10 分钟',
          selected: this.item.expectedMinutes === 10,
          compact: true,
          onSelect: () => this.onMinutesChange(this.item, 10)
        });
        ChoiceSelectionChip({
          label: '15 分钟',
          selected: this.item.expectedMinutes === 15,
          compact: true,
          onSelect: () => this.onMinutesChange(this.item, 15)
        });
        ChoiceSelectionChip({
          label: '20 分钟',
          selected: this.item.expectedMinutes === 20,
          compact: true,
          onSelect: () => this.onMinutesChange(this.item, 20)
        });
        ChoiceSelectionChip({
          label: '30 分钟',
          selected: this.item.expectedMinutes === 30,
          compact: true,
          onSelect: () => this.onMinutesChange(this.item, 30)
        });
        ChoiceSelectionChip({
          label: '45 分钟',
          selected: this.item.expectedMinutes === 45,
          compact: true,
          onSelect: () => this.onMinutesChange(this.item, 45)
        });
      }
      .width('100%');

      TextInput({ text: `${this.item.expectedMinutes}` })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          let minutes = Math.round(Number(value));
          if (!Number.isFinite(minutes)) return;
          if (minutes < 1) minutes = 1;
          if (minutes > 240) minutes = 240;
          this.onMinutesChange(this.item, minutes);
        });

      Text('教材 / 页码').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.item.textbookRef })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onTextbookRefChange(this.item, value));

      Column({ space: 5 }) {
        Text(this.item.sourceEvidence.sourceLabel.length > 0 ?
          this.item.sourceEvidence.sourceLabel : '老师原文')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.item.sourceEvidence.excerpt)
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(13)
      .backgroundColor(this.item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
    .width('100%');
  }
}
