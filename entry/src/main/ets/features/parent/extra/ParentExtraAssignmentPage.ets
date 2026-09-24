import { AppTheme } from '../../../common/theme/AppTheme';
import { DeadlinePickerField } from '../../../components/assignment/DeadlinePickerField';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Subject } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';
import { ExtraAssignmentDraft, ParentExtraAssignmentViewModel } from './ParentExtraAssignmentViewModel';

@Component
export struct ParentExtraAssignmentPage {
  @State private category: Subject = Subject.READING;
  @State private title: string = '';
  @State private instruction: string = '';
  @State private dueText: string = '今天';
  @State private expectedMinutesText: string = '20';
  @State private busy: boolean = false;
  @State private message: string = '';
  @State private messageError: boolean = false;
  onBack: () => void = () => {};
  onCreated: () => void = () => {};

  private readonly viewModel: ParentExtraAssignmentViewModel =
    new ParentExtraAssignmentViewModel(DefaultAssignmentRepository.instance);

  private expectedMinutes(): number {
    let value = Number(this.expectedMinutesText.trim());
    if (!Number.isFinite(value) || value < 1 || value > 240 || Math.floor(value) !== value) return -1;
    return value;
  }

  private dueAtEpochMs(): number {
    let text = this.dueText.trim();
    if (text.length === 0) return 0;
    let value = AssignmentDueDate.resolveDueAtEpochMs(text, Date.now());
    return value > 0 ? value : -1;
  }

  private async createTask(): Promise<void> {
    if (this.busy) return;
    let title = this.title.trim();
    let instruction = this.instruction.trim();
    if (title.length === 0) {
      this.showError('请填写任务名称');
      return;
    }
    if (instruction.length === 0) {
      this.showError('请填写完成要求');
      return;
    }
    let expectedMinutes = this.expectedMinutes();
    if (expectedMinutes < 0) {
      this.showError('预计用时请输入 1～240 分钟的整数');
      return;
    }
    let dueAt = this.dueAtEpochMs();
    if (dueAt < 0) {
      this.showError('请选择有效的截止日期和时间');
      return;
    }

    this.busy = true;
    this.message = '';
    this.messageError = false;
    try {
      let dueText = dueAt > 0 ? this.dueText.trim() : '未定';
      let draft: ExtraAssignmentDraft = {
        category: this.category,
        title: title,
        instruction: instruction,
        dueAtEpochMs: dueAt,
        dueText: dueText,
        expectedMinutes: expectedMinutes
      };
      await this.viewModel.create(draft);
      this.message = `已布置给 ${this.viewModel.student().name}`;
      this.onCreated();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '任务布置失败，请稍后重试';
      this.messageError = true;
    } finally {
      this.busy = false;
    }
  }

  private showError(message: string): void {
    this.message = message;
    this.messageError = true;
  }

  @Builder
  private CategoryOption(label: string, value: Subject) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(AppTheme.MIN_TOUCH_TARGET)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(this.category === value ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.category === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(this.category === value ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(() => this.category = value);
  }

  @Builder
  private CategorySection() {
    Column({ space: 10 }) {
      Text('任务分类').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Row({ space: 8 }) {
        this.CategoryOption('阅读', Subject.READING);
        this.CategoryOption('朗读', Subject.READ_ALOUD);
        this.CategoryOption('体育', Subject.SPORTS);
      }
      .width('100%');
      Row({ space: 8 }) {
        this.CategoryOption('实践', Subject.PRACTICE);
        this.CategoryOption('兴趣', Subject.INTEREST);
        this.CategoryOption('其他', Subject.OTHER);
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private BasicSection() {
    Column({ space: 12 }) {
      Text('任务内容').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      TextInput({ placeholder: '例如：阅读《西游记》第三章', text: this.title })
        .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(15)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.title = value);
      TextArea({ placeholder: '写清楚完成要求，例如：读完后用三句话复述主要内容', text: this.instruction })
        .width('100%').height(116).fontSize(14).lineHeight(21)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.instruction = value);
    }
    .width('100%');
  }

  @Builder
  private TimingSection() {
    Column({ space: 10 }) {
      Text('时间安排').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      DeadlinePickerField({
        value: this.dueText,
        allowClear: true,
        onChange: (value: string) => this.dueText = value
      });
      Column({ space: 5 }) {
        Text('预计用时（分钟）').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '20', text: this.expectedMinutesText })
          .width('100%').height(AppTheme.INPUT_HEIGHT).fontSize(14)
          .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.expectedMinutesText = value);
      }
      .width('100%').alignItems(HorizontalAlign.Start);
    }
    .width('100%');
  }

  @Builder
  private Feedback() {
    if (this.message.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.messageError ? $r('sys.symbol.exclamationmark_circle_fill') : $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17).fontColor([this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS]);
        Text(this.message).layoutWeight(1).fontSize(13).lineHeight(19)
          .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%').padding(12)
      .backgroundColor(this.messageError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '布置课外任务',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 18 }) {
              this.CategorySection();
              this.BasicSection();
              this.TimingSection();
            }
            .width('100%')
            .padding(AppTheme.PHONE_CARD_PADDING)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);
            this.Feedback();
            Button(this.busy ? '正在布置…' : '布置任务', { type: ButtonType.Normal })
              .width('100%').height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.busy)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.createTask(); });
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off);
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: AppTheme.DEEP_PAGE_TOP_PADDING });
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
