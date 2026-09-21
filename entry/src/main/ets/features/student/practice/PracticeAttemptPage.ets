import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { PracticeSubmitConfirmDialog } from '../../../components/practice/PracticeSubmitConfirmDialog';
import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeNote,
  PracticePreviousAnswer,
  PracticePreviousNote,
  PracticeQuestion,
  PracticeQuestionOption,
  PracticeQuestionType
} from '../../../domain/model/practice/PracticeModels';
import { PracticeAttemptViewModel } from './PracticeAttemptViewModel';

@Component
export struct PracticeAttemptPage {
  @Prop attemptId: string = '';
  @State private attempt: PracticeAttempt | null = null;
  @State private answers: PracticeAnswer[] = [];
  @State private notes: PracticeNote[] = [];
  @State private currentIndex: number = 0;
  @State private currentAnswer: string = '';
  @State private currentNote: string = '';
  @State private hintVisible: boolean = false;
  @State private showPreviousAnswer: boolean = false;
  @State private saving: boolean = false;
  @State private submitting: boolean = false;
  @State private errorMessage: string = '';
  @State private unansweredCount: number = 0;
  @State private availableWidthVp: number = 390;
  onBack: () => void = () => {};
  onSubmitted: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticeAttemptViewModel = new PracticeAttemptViewModel();

  private submitDialogController: CustomDialogController = new CustomDialogController({
    builder: PracticeSubmitConfirmDialog({
      unansweredCount: $unansweredCount,
      onConfirm: () => void this.submitNow()
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    void this.load();
  }

  private contentScale(): number {
    let scale = this.availableWidthVp / AppTheme.PRACTICE_ATTEMPT_SCALE_REFERENCE_WIDTH;
    if (!Number.isFinite(scale) || scale < 1) return 1;
    if (scale > AppTheme.PRACTICE_ATTEMPT_MAX_SCALE) return AppTheme.PRACTICE_ATTEMPT_MAX_SCALE;
    return scale;
  }

  private scaled(value: number): number {
    return Math.round(value * this.contentScale());
  }

  private headerTitle(): string {
    if (this.attempt !== null && this.attempt.mode === PracticeAttemptMode.WRONG_ONLY) return '错题专项';
    return '套卷练习';
  }

  private headerSubtitle(): string {
    if (this.attempt === null) return '';
    return `第 ${this.currentIndex + 1} / ${this.attempt.questionCount} 题`;
  }

  private async load(): Promise<void> {
    this.errorMessage = '';
    try {
      let loaded = await this.viewModel.load(this.attemptId);
      this.attempt = loaded;
      this.answers = loaded.answers.slice();
      this.notes = loaded.notes.slice();
      this.currentIndex = 0;
      this.showPreviousAnswer = false;
      this.syncCurrentDraft();
      if (loaded.status === PracticeAttemptStatus.SUBMITTED) this.onSubmitted(loaded.id);
    } catch {
      this.errorMessage = '练习加载失败，请检查网络后重试。';
    }
  }

  private currentQuestion(): PracticeQuestion | null {
    if (this.attempt === null || this.currentIndex < 0 || this.currentIndex >= this.attempt.questions.length) return null;
    return this.attempt.questions[this.currentIndex];
  }

  private answerFor(questionId: string): string {
    for (let answer of this.answers) if (answer.questionId === questionId) return answer.answerValue;
    return '';
  }

  private noteFor(questionId: string): string {
    for (let note of this.notes) if (note.questionId === questionId) return note.content;
    return '';
  }

  private previousAnswerFor(questionId: string): PracticePreviousAnswer | null {
    if (this.attempt === null) return null;
    for (let answer of this.attempt.previousAnswers) {
      if (answer.questionId === questionId) return answer;
    }
    return null;
  }

  private previousNoteFor(questionId: string): PracticePreviousNote | null {
    if (this.attempt === null) return null;
    for (let note of this.attempt.previousNotes) {
      if (note.questionId === questionId) return note;
    }
    return null;
  }

  private hasPreviousContext(): boolean {
    if (this.attempt === null) return false;
    return this.attempt.previousAnswers.length > 0 || this.attempt.previousNotes.length > 0;
  }

  private syncCurrentDraft(): void {
    let question = this.currentQuestion();
    this.currentAnswer = question === null ? '' : this.answerFor(question.id);
    this.currentNote = question === null ? '' : this.noteFor(question.id);
    this.hintVisible = false;
  }

  private isAnswered(questionId: string): boolean {
    return this.answerFor(questionId).trim().length > 0;
  }

  private async saveCurrentAnswer(): Promise<boolean> {
    let question = this.currentQuestion();
    if (question === null) return true;
    let normalized = this.currentAnswer.trim();
    let old = this.answerFor(question.id);
    if (normalized === old) return true;
    if (normalized.length === 0 && old.length === 0) return true;
    this.saving = true;
    this.errorMessage = '';
    try {
      let saved = await this.viewModel.save(this.attemptId, question.id, normalized);
      this.upsertAnswer(saved);
      return true;
    } catch {
      this.errorMessage = '答案保存失败，请检查网络后重试。';
      return false;
    } finally {
      this.saving = false;
    }
  }

  private async saveCurrentNote(): Promise<boolean> {
    let question = this.currentQuestion();
    if (question === null) return true;
    let normalized = this.currentNote.trim();
    let old = this.noteFor(question.id);
    if (normalized === old) return true;
    if (normalized.length > 500) {
      this.errorMessage = '单题笔记不能超过500字。';
      return false;
    }

    this.saving = true;
    this.errorMessage = '';
    try {
      if (normalized.length === 0) {
        await this.viewModel.deleteNote(this.attemptId, question.id);
        this.removeNote(question.id);
      } else {
        let saved = await this.viewModel.saveNote(this.attemptId, question.id, normalized);
        this.upsertNote(saved);
      }
      return true;
    } catch {
      this.errorMessage = '笔记保存失败，请检查网络后重试。';
      return false;
    } finally {
      this.saving = false;
    }
  }

  private async saveCurrentDraft(): Promise<boolean> {
    if (!await this.saveCurrentAnswer()) return false;
    return await this.saveCurrentNote();
  }

  private upsertAnswer(saved: PracticeAnswer): void {
    let next: PracticeAnswer[] = [];
    let replaced = false;
    for (let answer of this.answers) {
      if (answer.questionId === saved.questionId) {
        next.push(saved);
        replaced = true;
      } else {
        next.push(answer);
      }
    }
    if (!replaced) next.push(saved);
    this.answers = next;
  }

  private upsertNote(saved: PracticeNote): void {
    let next: PracticeNote[] = [];
    let replaced = false;
    for (let note of this.notes) {
      if (note.questionId === saved.questionId) {
        next.push(saved);
        replaced = true;
      } else {
        next.push(note);
      }
    }
    if (!replaced) next.push(saved);
    this.notes = next;
  }

  private removeNote(questionId: string): void {
    let next: PracticeNote[] = [];
    for (let note of this.notes) {
      if (note.questionId !== questionId) next.push(note);
    }
    this.notes = next;
  }

  private async moveTo(index: number): Promise<void> {
    if (this.saving || this.submitting || this.attempt === null) return;
    if (index < 0 || index >= this.attempt.questions.length || index === this.currentIndex) return;
    if (!await this.saveCurrentDraft()) return;
    this.currentIndex = index;
    this.syncCurrentDraft();
  }

  private async requestBack(): Promise<void> {
    if (this.saving || this.submitting) return;
    if (!await this.saveCurrentDraft()) return;
    this.onBack();
  }

  private async requestSubmit(): Promise<void> {
    if (this.submitting || this.saving || this.attempt === null) return;
    if (!await this.saveCurrentDraft()) return;
    let answered = 0;
    for (let question of this.attempt.questions) if (this.isAnswered(question.id)) answered++;
    this.unansweredCount = this.attempt.questions.length - answered;
    if (this.unansweredCount > 0) {
      this.submitDialogController.open();
      return;
    }
    await this.submitNow();
  }

  private async submitNow(): Promise<void> {
    if (this.submitting) return;
    this.submitting = true;
    this.errorMessage = '';
    try {
      await this.viewModel.submit(this.attemptId);
      this.onSubmitted(this.attemptId);
    } catch {
      this.errorMessage = '交卷失败，请检查网络后重试。';
    } finally {
      this.submitting = false;
    }
  }

  private updateNote(value: string): void {
    if (value.length <= 500) this.currentNote = value;
  }

  @Builder
  private CurrentQuestionAnswer() {
    if (this.attempt !== null && this.currentIndex >= 0 &&
      this.currentIndex < this.attempt.questions.length) {
      if (this.attempt.questions[this.currentIndex].type === PracticeQuestionType.SINGLE_CHOICE) {
        Column({ space: this.scaled(10) }) {
          ForEach(
            this.attempt.questions[this.currentIndex].options,
            (option: PracticeQuestionOption) => {
              Button(`${option.key}. ${option.label}`, { type: ButtonType.Normal })
                .width('100%')
                .height(this.scaled(50))
                .fontSize(this.scaled(14))
                .fontColor(this.currentAnswer === option.key ? AppTheme.PRIMARY : AppTheme.TEXT)
                .backgroundColor(this.currentAnswer === option.key ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE)
                .border({
                  width: 1,
                  color: this.currentAnswer === option.key ? AppTheme.PRIMARY : AppTheme.BORDER
                })
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .onClick(() => this.currentAnswer = option.key);
            },
            (option: PracticeQuestionOption) =>
              `${this.currentIndex}:${option.key}:${option.label}`
          );
        }
        .width('100%');
      } else {
        TextInput({
          placeholder: this.attempt.questions[this.currentIndex].type === PracticeQuestionType.NUMBER ?
            '输入答案' : '输入你的答案',
          text: this.currentAnswer
        })
          .width('100%')
          .height(this.scaled(AppTheme.INPUT_HEIGHT))
          .fontSize(this.scaled(16))
          .backgroundColor(AppTheme.SURFACE)
          .border({ width: 1, color: AppTheme.BORDER })
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.currentAnswer = value);
      }
    }
  }

  @Builder
  private QuestionNavigation() {
    Scroll() {
      Row({ space: this.scaled(7) }) {
        if (this.attempt !== null) {
          ForEach(this.attempt.questions, (question: PracticeQuestion, index: number) => {
            Text(`${index + 1}`)
              .width(this.scaled(36))
              .height(this.scaled(36))
              .textAlign(TextAlign.Center)
              .fontSize(this.scaled(13))
              .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.currentIndex === index ? AppTheme.TEXT_ON_PRIMARY :
                (this.isAnswered(question.id) ? AppTheme.SUCCESS : AppTheme.SUBTEXT))
              .backgroundColor(this.currentIndex === index ? AppTheme.PRIMARY :
                (this.isAnswered(question.id) ? AppTheme.SUCCESS_SOFT : AppTheme.SURFACE_EMPHASIS))
              .borderRadius(this.scaled(18))
              .onClick(() => void this.moveTo(index));
          }, (question: PracticeQuestion) => question.id);
        }
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off);
  }

  @Builder
  private AttemptContext() {
    if (this.attempt !== null) {
      Column() {
        Column({ space: this.scaled(8) }) {
          this.QuestionNavigation();
          if (this.hasPreviousContext()) {
            Row() {
              Text(`第 ${this.attempt.attemptNo} 次练习`)
                .fontSize(this.scaled(12))
                .fontColor(AppTheme.SUBTEXT);
              Blank();
              Text(this.showPreviousAnswer ? '隐藏上次作答' : '显示上次作答')
                .fontSize(this.scaled(12))
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.PRIMARY)
                .constraintSize({ minHeight: this.scaled(AppTheme.MIN_TOUCH_TARGET) })
                .padding({ left: this.scaled(10), right: this.scaled(2) })
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText(this.showPreviousAnswer ? '隐藏上次作答' : '显示上次作答')
                .onClick(() => this.showPreviousAnswer = !this.showPreviousAnswer);
            }
            .width('100%');
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_ATTEMPT_READABLE_MAX_WIDTH })
        .padding({
          left: this.scaled(AppTheme.PAGE_PADDING),
          right: this.scaled(AppTheme.PAGE_PADDING),
          top: this.scaled(12),
          bottom: this.scaled(8)
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(AppTheme.SURFACE);
    }
  }

  @Builder
  private QuestionContent() {
    Column({ space: this.scaled(16) }) {
      if (this.currentQuestion() !== null) {
        Column({ space: this.scaled(12) }) {
          Text(`第 ${this.currentQuestion()!.orderNo} 题`)
            .width('100%')
            .fontSize(this.scaled(12))
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          Text(this.currentQuestion()!.stem)
            .width('100%')
            .fontSize(this.scaled(20))
            .fontWeight(FontWeight.Medium)
            .lineHeight(this.scaled(30))
            .fontColor(AppTheme.TEXT);

          this.CurrentQuestionAnswer();

          Column({ space: this.scaled(7) }) {
            Row() {
              Text('我的笔记')
                .fontSize(this.scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Blank();
              Text(`${this.currentNote.length}/500`)
                .fontSize(this.scaled(11))
                .fontColor(AppTheme.TERTIARY_TEXT);
            }
            .width('100%');
            TextInput({ placeholder: '记录这道题的思路、易错点…', text: this.currentNote })
              .width('100%')
              .height(this.scaled(AppTheme.INPUT_HEIGHT))
              .fontSize(this.scaled(14))
              .backgroundColor(AppTheme.SURFACE_SUBTLE)
              .border({ width: 1, color: AppTheme.BORDER })
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .onChange((value: string) => this.updateNote(value));
          }
          .width('100%');

          if (this.showPreviousAnswer &&
            (this.previousAnswerFor(this.currentQuestion()!.id) !== null ||
             this.previousNoteFor(this.currentQuestion()!.id) !== null)) {
            Column({ space: this.scaled(6) }) {
              Text('上次练习')
                .width('100%')
                .fontSize(this.scaled(12))
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.SUBTEXT);
              if (this.previousAnswerFor(this.currentQuestion()!.id) !== null) {
                Text(`上次作答：${this.previousAnswerFor(this.currentQuestion()!.id)!.answerValue}`)
                  .width('100%')
                  .fontSize(this.scaled(14))
                  .fontColor(AppTheme.TEXT);
                Text(this.previousAnswerFor(this.currentQuestion()!.id)!.correct ? '上次答对' : '上次需订正')
                  .width('100%')
                  .fontSize(this.scaled(12))
                  .fontColor(this.previousAnswerFor(this.currentQuestion()!.id)!.correct ?
                    AppTheme.SUCCESS : AppTheme.WARNING);
              }
              if (this.previousNoteFor(this.currentQuestion()!.id) !== null) {
                Text(`上次笔记：${this.previousNoteFor(this.currentQuestion()!.id)!.content}`)
                  .width('100%')
                  .fontSize(this.scaled(12))
                  .lineHeight(this.scaled(18))
                  .fontColor(AppTheme.SUBTEXT);
              }
            }
            .width('100%')
            .padding(this.scaled(12))
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
          }
        }
        .width('100%')
        .padding(this.scaled(AppTheme.CARD_PADDING))
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CARD_RADIUS);

        if (this.currentQuestion()!.hints.length > 0) {
          Column({ space: this.scaled(8) }) {
            Text(this.hintVisible ? '收起提示' : '需要提示？')
              .width('100%')
              .fontSize(this.scaled(13))
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY)
              .onClick(() => this.hintVisible = !this.hintVisible);
            if (this.hintVisible) {
              Text(this.currentQuestion()!.hints[0])
                .width('100%')
                .fontSize(this.scaled(13))
                .lineHeight(this.scaled(20))
                .fontColor(AppTheme.SUBTEXT);
            }
          }
          .width('100%')
          .padding(this.scaled(14))
          .backgroundColor(AppTheme.PRIMARY_FAINT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
        }
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(this.scaled(13))
          .fontColor(AppTheme.DANGER)
          .padding(this.scaled(12))
          .backgroundColor(AppTheme.DANGER_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      }
    }
    .width('100%');
  }

  @Builder
  private FooterControls() {
    if (this.attempt !== null) {
      Column() {
        Row({ space: this.scaled(10) }) {
          Button('上一题', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(this.scaled(AppTheme.BUTTON_HEIGHT))
            .fontSize(this.scaled(14))
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(this.currentIndex > 0 ? AppTheme.TEXT : AppTheme.DISABLED)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(this.currentIndex > 0 && !this.saving && !this.submitting)
            .onClick(() => void this.moveTo(this.currentIndex - 1));
          if (this.currentIndex < this.attempt.questions.length - 1) {
            Button('下一题', { type: ButtonType.Normal })
              .layoutWeight(2)
              .height(this.scaled(AppTheme.BUTTON_HEIGHT))
              .fontSize(this.scaled(14))
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.saving && !this.submitting)
              .onClick(() => void this.moveTo(this.currentIndex + 1));
          } else {
            Button(this.submitting ? '交卷中…' : '交卷', { type: ButtonType.Normal })
              .layoutWeight(2)
              .height(this.scaled(AppTheme.BUTTON_HEIGHT))
              .fontSize(this.scaled(14))
              .backgroundColor(this.submitting ? AppTheme.DISABLED : AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.saving && !this.submitting)
              .onClick(() => void this.requestSubmit());
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_ATTEMPT_READABLE_MAX_WIDTH })
        .padding({
          left: this.scaled(AppTheme.PAGE_PADDING),
          right: this.scaled(AppTheme.PAGE_PADDING),
          top: this.scaled(10),
          bottom: this.scaled(14)
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
    }
  }

  build() {
    Column() {
      Column() {
        DeepPageHeader({
          title: this.headerTitle(),
          subtitle: this.headerSubtitle(),
          trailingText: this.saving ? '保存中…' : '',
          backAccessibilityText: '返回练习',
          onBack: () => void this.requestBack()
        });
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PRACTICE_ATTEMPT_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });

      Divider().width('100%').color(AppTheme.DIVIDER);

      this.AttemptContext();

      Scroll() {
        Column() {
          Column() {
            this.QuestionContent();
          }
          .width('100%')
          .constraintSize({ maxWidth: AppTheme.PRACTICE_ATTEMPT_READABLE_MAX_WIDTH })
          .padding({
            left: this.scaled(AppTheme.PAGE_PADDING),
            right: this.scaled(AppTheme.PAGE_PADDING),
            top: this.scaled(AppTheme.DEEP_PAGE_CONTENT_GAP),
            bottom: this.scaled(AppTheme.DEEP_PAGE_BOTTOM_PADDING)
          });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      this.FooterControls();
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
