import { AppTheme } from '../../common/theme/AppTheme';
import { Subject } from '../../domain/model/HomeworkModels';
import { DeadlinePickerField } from './DeadlinePickerField';
import { ChoiceSelectionChip } from '../selection/SelectionControls';

@Component
export struct AssignmentEditForm {
  @Prop subject: Subject = Subject.OTHER;
  @Prop subjectEditable: boolean = true;
  @Prop title: string = '';
  @Prop instruction: string = '';
  @Prop dueText: string = '';
  @Prop expectedMinutes: number = 20;
  @Prop textbookRef: string = '';

  onSubjectChange: (subject: Subject) => void = (_subject: Subject) => {};
  onTitleChange: (value: string) => void = (_value: string) => {};
  onInstructionChange: (value: string) => void = (_value: string) => {};
  onDueTextChange: (value: string) => void = (_value: string) => {};
  onMinutesChange: (minutes: number) => void = (_minutes: number) => {};
  onTextbookRefChange: (value: string) => void = (_value: string) => {};

  private applyCustomMinutes(value: string): void {
    if (value.trim().length === 0) return;
    let minutes = Math.round(Number(value));
    if (!Number.isFinite(minutes)) return;
    if (minutes < 1) minutes = 1;
    if (minutes > 240) minutes = 240;
    this.onMinutesChange(minutes);
  }

  @Builder
  private SubjectSection() {
    Column({ space: 7 }) {
      Text('科目').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      if (this.subjectEditable) {
        Row({ space: 8 }) {
          ChoiceSelectionChip({
            label: Subject.CHINESE,
            selected: this.subject === Subject.CHINESE,
            onSelect: () => this.onSubjectChange(Subject.CHINESE)
          });
          ChoiceSelectionChip({
            label: Subject.MATH,
            selected: this.subject === Subject.MATH,
            onSelect: () => this.onSubjectChange(Subject.MATH)
          });
          ChoiceSelectionChip({
            label: Subject.ENGLISH,
            selected: this.subject === Subject.ENGLISH,
            onSelect: () => this.onSubjectChange(Subject.ENGLISH)
          });
        }
        .width('100%');
      } else {
        Row() {
          Text(this.subject)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .padding({ left: 13, right: 13, top: 9, bottom: 9 })
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
          Blank();
          Text('发布后科目保持不变')
            .fontSize(11)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private DurationSection() {
    Column({ space: 7 }) {
      Text('预计用时（分钟）')
        .width('100%')
        .maxLines(1)
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
      Scroll() {
        Row({ space: 6 }) {
          ChoiceSelectionChip({
            label: '10',
            selected: this.expectedMinutes === 10,
            compact: true,
            onSelect: () => this.onMinutesChange(10)
          });
          ChoiceSelectionChip({
            label: '15',
            selected: this.expectedMinutes === 15,
            compact: true,
            onSelect: () => this.onMinutesChange(15)
          });
          ChoiceSelectionChip({
            label: '20',
            selected: this.expectedMinutes === 20,
            compact: true,
            onSelect: () => this.onMinutesChange(20)
          });
          ChoiceSelectionChip({
            label: '30',
            selected: this.expectedMinutes === 30,
            compact: true,
            onSelect: () => this.onMinutesChange(30)
          });
          ChoiceSelectionChip({
            label: '45',
            selected: this.expectedMinutes === 45,
            compact: true,
            onSelect: () => this.onMinutesChange(45)
          });
          TextInput({ text: `${this.expectedMinutes}`, placeholder: '自定义' })
            .width(96)
            .height(40)
            .fontSize(12)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CHIP_RADIUS)
            .textAlign(TextAlign.Center)
            .onChange((value: string) => this.applyCustomMinutes(value));
          Text('分钟')
            .maxLines(1)
            .fontSize(11)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }

  build() {
    Column({ space: 12 }) {
      this.SubjectSection();

      Text('作业标题').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.title })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onTitleChange(value));

      Text('老师要求').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextArea({ text: this.instruction })
        .width('100%')
        .height(92)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onInstructionChange(value));

      Text('截止时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      DeadlinePickerField({
        value: this.dueText,
        allowClear: true,
        onChange: (value: string) => this.onDueTextChange(value)
      });

      this.DurationSection();

      Text('教材 / 页码').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: this.textbookRef })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.onTextbookRefChange(value));
    }
    .width('100%');
  }
}
