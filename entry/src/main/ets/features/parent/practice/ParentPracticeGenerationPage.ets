import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import {
  PracticeAudienceCandidate,
  PracticeDifficulty,
  PracticeGenerationDraftQuestion,
  PracticeGenerationResult,
  PracticeQuestionOption,
  PracticePublishScope,
  PracticeQuestionType,
  PracticeSubject,
  PracticeTrack
} from '../../../domain/model/practice/PracticeModels';
import { ParentPracticeGenerationViewModel } from './ParentPracticeGenerationViewModel';

@Component
export struct ParentPracticeGenerationPage {
  @State private subject: PracticeSubject = PracticeSubject.MATH;
  @State private track: PracticeTrack = PracticeTrack.TEXTBOOK_SYNC;
  @State private difficulty: PracticeDifficulty = PracticeDifficulty.L1;
  @State private questionCount: number = 12;
  @State private requirement: string = '';
  @State private result: PracticeGenerationResult | null = null;
  @State private publishScope: PracticePublishScope = PracticePublishScope.CURRENT;
  @State private selectedStudentIds: string[] = [];
  @State private generating: boolean = false;
  @State private publishing: boolean = false;
  @State private message: string = '';
  @State private messageError: boolean = false;

  onBack: () => void = () => {};
  onPublished: () => void = () => {};

  private readonly viewModel: ParentPracticeGenerationViewModel =
    new ParentPracticeGenerationViewModel();

  aboutToAppear(): void {
    this.resetAudienceSelection();
  }

  private resetAudienceSelection(): void {
    this.publishScope = PracticePublishScope.CURRENT;
    this.selectedStudentIds = [this.viewModel.activeStudentId()];
  }

  private async generate(): Promise<void> {
    if (this.generating || this.publishing) return;
    if (this.requirement.trim().length === 0) {
      this.showMessage('请先填写希望孩子重点练习的内容', true);
      return;
    }
    this.generating = true;
    this.message = '';
    try {
      this.result = await this.viewModel.generate(
        this.subject, this.track, this.difficulty, this.questionCount, this.requirement);
      if (this.result.paper === null) {
        this.showMessage(this.result.errorMessage.length > 0 ?
          this.result.errorMessage : 'AI没有生成可预览的练习，请重新生成', true);
      } else {
        this.resetAudienceSelection();
        this.showMessage('已生成练习，请预览并选择发布对象', false);
      }
    } catch (error) {
      this.result = null;
      this.showMessage(error instanceof Error ? error.message : 'AI出题失败，请稍后重试', true);
    } finally {
      this.generating = false;
    }
  }

  private async publish(): Promise<void> {
    if (this.result === null || this.result.paper === null || this.publishing || this.generating) return;
    let blocked = this.publishBlockedReason(this.result.paper);
    if (blocked.length > 0) {
      this.showMessage(blocked, true);
      return;
    }
    let targets = this.targetStudentIds();
    this.publishing = true;
    this.message = '';
    try {
      let published = await this.viewModel.publish(this.result.generationId, this.publishScope, targets);
      this.showMessage(`练习已发布给${published.targetStudentIds.length}个学生`, false);
      this.onPublished();
    } catch (error) {
      this.showMessage(error instanceof Error ? error.message : '发布练习失败，请稍后重试', true);
    } finally {
      this.publishing = false;
    }
  }

  private showMessage(value: string, error: boolean): void {
    this.message = value;
    this.messageError = error;
  }

  private selectSubject(value: PracticeSubject): void {
    if (this.generating || this.publishing) return;
    this.subject = value;
    this.result = null;
  }

  private selectTrack(value: PracticeTrack): void {
    if (this.generating || this.publishing) return;
    this.track = value;
    this.result = null;
  }

  private selectDifficulty(value: PracticeDifficulty): void {
    if (this.generating || this.publishing) return;
    this.difficulty = value;
    this.result = null;
  }

  private selectQuestionCount(value: number): void {
    if (this.generating || this.publishing) return;
    this.questionCount = value;
    this.result = null;
  }

  private selectPublishScope(scope: PracticePublishScope): void {
    if (this.generating || this.publishing) return;
    this.publishScope = scope;
    if (scope === PracticePublishScope.CURRENT) {
      this.selectedStudentIds = [this.viewModel.activeStudentId()];
    }
  }

  private isStudentSelected(studentId: string): boolean {
    return this.selectedStudentIds.indexOf(studentId) >= 0;
  }

  private candidate(studentId: string): PracticeAudienceCandidate | null {
    if (this.result === null) return null;
    for (let candidate of this.result.audienceCandidates) {
      if (candidate.studentId === studentId) return candidate;
    }
    return null;
  }

  private toggleStudent(candidate: PracticeAudienceCandidate): void {
    if (this.result === null || this.result.paper === null || this.generating || this.publishing) return;
    if (!candidate.compatible) return;
    let next: string[] = [];
    let found = false;
    for (let id of this.selectedStudentIds) {
      if (id === candidate.studentId) found = true;
      else next.push(id);
    }
    if (!found) next.push(candidate.studentId);
    this.selectedStudentIds = next;
  }

  private targetStudentIds(): string[] {
    if (this.publishScope === PracticePublishScope.CURRENT) {
      return [this.viewModel.activeStudentId()];
    }
    if (this.publishScope === PracticePublishScope.ALL) {
      let all: string[] = [];
      if (this.result !== null) {
        for (let candidate of this.result.audienceCandidates) all.push(candidate.studentId);
      }
      return all;
    }
    return this.selectedStudentIds.slice();
  }

  private publishBlockedReason(): string {
    if (this.result === null || this.result.paper === null) return '请先生成练习';

    if (this.publishScope === PracticePublishScope.CURRENT) {
      let current = this.candidate(this.viewModel.activeStudentId());
      if (current === null) return '当前学生不在可发布范围';
      return current.compatible ? '' : `${current.studentName}：${current.reason}`;
    }

    if (this.publishScope === PracticePublishScope.SELECTED && this.selectedStudentIds.length === 0) {
      return '请至少选择一个学生';
    }

    if (this.result.audienceCandidates.length === 0) return '当前家庭没有可发布学生';

    let incompatible: string[] = [];
    for (let candidate of this.result.audienceCandidates) {
      let included = this.publishScope === PracticePublishScope.ALL ||
        this.isStudentSelected(candidate.studentId);
      if (included && !candidate.compatible) {
        incompatible.push(`${candidate.studentName}：${candidate.reason}`);
      }
    }
    return incompatible.length === 0 ? '' : '以下学生暂不能使用本套练习：' + incompatible.join('；');
  }

  private questionTypeLabel(type: PracticeQuestionType): string {
    if (type === PracticeQuestionType.SINGLE_CHOICE) return '单选题';
    if (type === PracticeQuestionType.FILL_BLANK) return '填空题';
    if (type === PracticeQuestionType.NUMBER) return '数字题';
    return '练习题';
  }

  @Builder
  private ContextCard() {
    let student = this.viewModel.student();
    Column({ space: 6 }) {
      Row() {
        Text('出题对象')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(student.name)
          .fontSize(AppTheme.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%');
      Text(`${student.grade} · ${student.semester}`)
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      if (student.textbookSummary.length > 0) {
        Text('教材：' + student.textbookSummary)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      } else if (this.track === PracticeTrack.TEXTBOOK_SYNC) {
        Text('教材同步出题需要先在孩子资料中配置教材信息')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private GenerationForm() {
    Column({ space: 15 }) {
      Text('科目')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '语文',
          selected: this.subject === PracticeSubject.CHINESE,
          onSelect: () => this.selectSubject(PracticeSubject.CHINESE)
        });
        SegmentedSelectionButton({
          label: '数学',
          selected: this.subject === PracticeSubject.MATH,
          onSelect: () => this.selectSubject(PracticeSubject.MATH)
        });
        SegmentedSelectionButton({
          label: '英语',
          selected: this.subject === PracticeSubject.ENGLISH,
          onSelect: () => this.selectSubject(PracticeSubject.ENGLISH)
        });
      }
      .width('100%');

      Text('题库类型')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '教材同步',
          selected: this.track === PracticeTrack.TEXTBOOK_SYNC,
          onSelect: () => this.selectTrack(PracticeTrack.TEXTBOOK_SYNC)
        });
        SegmentedSelectionButton({
          label: '课外拓展',
          selected: this.track === PracticeTrack.EXTRACURRICULAR,
          onSelect: () => this.selectTrack(PracticeTrack.EXTRACURRICULAR)
        });
      }
      .width('100%');

      Text('难度')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        SegmentedSelectionButton({
          label: '基础',
          selected: this.difficulty === PracticeDifficulty.L1,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L1)
        });
        SegmentedSelectionButton({
          label: '提升',
          selected: this.difficulty === PracticeDifficulty.L2,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L2)
        });
        SegmentedSelectionButton({
          label: '挑战',
          selected: this.difficulty === PracticeDifficulty.L3,
          onSelect: () => this.selectDifficulty(PracticeDifficulty.L3)
        });
      }
      .width('100%');

      Text('题量')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 6 }) {
        SegmentedSelectionButton({
          label: '5题', selected: this.questionCount === 5,
          onSelect: () => this.selectQuestionCount(5)
        });
        SegmentedSelectionButton({
          label: '10题', selected: this.questionCount === 10,
          onSelect: () => this.selectQuestionCount(10)
        });
        SegmentedSelectionButton({
          label: '12题', selected: this.questionCount === 12,
          onSelect: () => this.selectQuestionCount(12)
        });
        SegmentedSelectionButton({
          label: '15题', selected: this.questionCount === 15,
          onSelect: () => this.selectQuestionCount(15)
        });
      }
      .width('100%');

      Column({ space: 6 }) {
        Text('我希望重点练习')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        TextArea({
          placeholder: '例如：100以内退位减法，多一些生活应用题，重点区分加法和减法',
          text: this.requirement
        })
          .width('100%')
          .height(118)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => {
            this.requirement = value.length <= 500 ? value : value.substring(0, 500);
            this.result = null;
          });
        Text(`${this.requirement.length}/500`)
          .width('100%')
          .textAlign(TextAlign.End)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      Button(this.generating ? 'AI正在生成并校验…' : 'AI生成练习', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .enabled(!this.generating && !this.publishing)
        .fontSize(AppTheme.FORM_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.generating ? AppTheme.DISABLED : AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onClick(() => { void this.generate(); });
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_STANDARD)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_STANDARD);
  }

  @Builder
  private QuestionPreview(question: PracticeGenerationDraftQuestion) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(`${question.orderNo}. ${this.questionTypeLabel(question.type)}`)
          .fontSize(AppTheme.META_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
        Blank();
        if (question.tags.length > 0) {
          Text(question.tags[0])
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      Text(question.stem)
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.TEXT);

      if (question.options.length > 0) {
        Column({ space: 5 }) {
          ForEach(question.options, (option: PracticeQuestionOption) => {
            Text(`${option.key}. ${option.label}`)
              .width('100%')
              .fontSize(AppTheme.META_SIZE)
              .lineHeight(AppTheme.META_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT);
          }, (option: PracticeQuestionOption) => option.key);
        }
        .width('100%');
      }

      Text('答案：' + question.answerSpec)
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.SUCCESS);
      Text(question.explanation)
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .lineHeight(AppTheme.META_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      if (question.hints.length > 0) {
        Text(question.hints[0])
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private AudienceSelection() {
    Column({ space: 10 }) {
      Text('发布对象')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Row({ space: 6 }) {
        SegmentedSelectionButton({
          label: '当前学生',
          selected: this.publishScope === PracticePublishScope.CURRENT,
          onSelect: () => this.selectPublishScope(PracticePublishScope.CURRENT)
        });
        SegmentedSelectionButton({
          label: '选择学生',
          selected: this.publishScope === PracticePublishScope.SELECTED,
          onSelect: () => this.selectPublishScope(PracticePublishScope.SELECTED)
        });
        SegmentedSelectionButton({
          label: '全部学生',
          selected: this.publishScope === PracticePublishScope.ALL,
          onSelect: () => this.selectPublishScope(PracticePublishScope.ALL)
        });
      }
      .width('100%');

      if (this.result !== null && this.publishScope === PracticePublishScope.CURRENT) {
        let current = this.candidate(this.viewModel.activeStudentId());
        if (current !== null) {
          Text(`将发布给：${current.studentName} · ${current.grade} · ${current.semester}`)
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(current.compatible ? AppTheme.SUBTEXT : AppTheme.WARNING);
        }
      } else if (this.result !== null && this.publishScope === PracticePublishScope.SELECTED) {
        Column({ space: 7 }) {
          ForEach(this.result.audienceCandidates, (candidate: PracticeAudienceCandidate) => {
            let selected = this.isStudentSelected(candidate.studentId);
            Row({ space: 10 }) {
              Text(selected ? '✓' : '○')
                .fontSize(AppTheme.BODY_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(!candidate.compatible ? AppTheme.DISABLED :
                  selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
              Column({ space: 2 }) {
                Text(candidate.studentName)
                  .width('100%')
                  .fontSize(AppTheme.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(!candidate.compatible ? AppTheme.DISABLED : AppTheme.TEXT);
                Text(!candidate.compatible ? candidate.reason :
                  `${candidate.grade} · ${candidate.semester}`)
                  .width('100%')
                  .fontSize(AppTheme.CAPTION_SIZE)
                  .fontColor(!candidate.compatible ? AppTheme.WARNING : AppTheme.SUBTEXT);
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(selected && candidate.compatible ?
              AppTheme.PRIMARY_FAINT : AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(() => this.toggleStudent(candidate));
          }, (candidate: PracticeAudienceCandidate) => candidate.studentId);
        }
        .width('100%');
      } else if (this.result !== null) {
        Text(`将发布给家庭当前全部${this.result.audienceCandidates.length}个学生；以后新增的学生不会自动获得这套历史练习。`)
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }

      if (this.publishBlockedReason().length > 0) {
        Text(this.publishBlockedReason())
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.WARNING)
          .padding(10)
          .backgroundColor(AppTheme.WARNING_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private Preview() {
    if (this.result !== null && this.result.paper !== null) {
      Column({ space: 12 }) {
        Column({ space: 5 }) {
          Text(this.result.paper.title)
            .width('100%')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(`${this.viewModel.subjectLabel(this.result.paper.subject)} · ${this.viewModel.trackLabel(this.result.paper.track)} · ${this.viewModel.difficultyLabel(this.result.paper.difficulty)} · ${this.result.paper.questionCount}题 · 约${this.result.paper.estimatedMinutes}分钟`)
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
          Text(this.result.paper.description)
            .width('100%')
            .fontSize(AppTheme.BODY_SIZE)
            .lineHeight(AppTheme.BODY_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Text('题目预览')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);

        ForEach(this.result.paper.questions, (question: PracticeGenerationDraftQuestion) => {
          this.QuestionPreview(question);
        }, (question: PracticeGenerationDraftQuestion) => question.id);

        this.AudienceSelection();

        Row({ space: 10 }) {
          Button('重新生成', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.BUTTON_HEIGHT)
            .enabled(!this.generating && !this.publishing)
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(() => { void this.generate(); });
          Button(this.publishing ? '正在发布…' : `发布给${this.targetStudentIds().length}个学生`, { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.BUTTON_HEIGHT)
            .enabled(!this.generating && !this.publishing &&
              this.publishBlockedReason().length === 0)
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.publishing ? AppTheme.DISABLED : AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onClick(() => { void this.publish(); });
        }
        .width('100%');
      }
      .width('100%')
      .padding(AppTheme.CARD_PADDING_STANDARD)
      .backgroundColor(AppTheme.CARD_SURFACE)
      .borderRadius(AppTheme.CARD_RADIUS_STANDARD);
    }
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: 'AI生成练习',
          backAccessibilityText: '返回家长首页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: 12 }) {
            this.ContextCard();

            Text('由家长设置训练目标，生成结果会先经过质量校验并预览，确认后才会发布给孩子。')
              .width('100%')
              .fontSize(AppTheme.CAPTION_SIZE)
              .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT)
              .padding(12)
              .backgroundColor(AppTheme.PRIMARY_FAINT)
              .borderRadius(AppTheme.CONTROL_RADIUS);

            this.GenerationForm();

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

            this.Preview();
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);
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
