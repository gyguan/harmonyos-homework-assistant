import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import {
  PracticeAudienceCandidate,
  PracticeDifficulty,
  PracticeGenerationDraftQuestion,
  PracticeGenerationResult,
  PracticePublishScope,
  PracticeQuestionOption,
  PracticeQuestionType,
  PracticeSubject,
  PracticeTrack
} from '../../../domain/model/practice/PracticeModels';
import { ParentPracticeGenerationViewModel } from './ParentPracticeGenerationViewModel';

@Component
export struct ParentPracticeGenerationResultPage {
  @Prop subject: PracticeSubject = PracticeSubject.MATH;
  @Prop track: PracticeTrack = PracticeTrack.TEXTBOOK_SYNC;
  @Prop difficulty: PracticeDifficulty = PracticeDifficulty.L1;
  @Prop questionCount: number = 12;
  @Prop requirement: string = '';

  @State private result: PracticeGenerationResult | null = null;
  @State private publishScope: PracticePublishScope = PracticePublishScope.CURRENT;
  @State private selectedStudentIds: string[] = [];
  @State private generating: boolean = true;
  @State private publishing: boolean = false;
  @State private message: string = '';
  @State private messageError: boolean = false;

  onBack: () => void = () => {};
  onPublished: () => void = () => {};

  private readonly viewModel: ParentPracticeGenerationViewModel =
    new ParentPracticeGenerationViewModel();
  private generationStarted: boolean = false;

  aboutToAppear(): void {
    if (this.generationStarted) return;
    this.generationStarted = true;
    this.resetAudienceSelection();
    void this.generate();
  }

  private resetAudienceSelection(): void {
    this.publishScope = PracticePublishScope.CURRENT;
    this.selectedStudentIds = [this.viewModel.activeStudentId()];
  }

  private async generate(): Promise<void> {
    if (this.generating && this.result !== null) return;
    if (this.publishing) return;

    this.generating = true;
    this.result = null;
    this.message = '';
    this.messageError = false;
    try {
      let generated = await this.viewModel.generate(
        this.subject,
        this.track,
        this.difficulty,
        this.questionCount,
        this.requirement);
      this.result = generated;
      if (generated.paper === null) {
        this.showMessage(
          generated.errorMessage.length > 0 ?
            generated.errorMessage : 'AI没有生成可预览的练习，请重新生成',
          true);
      } else {
        this.resetAudienceSelection();
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
    let blocked = this.publishBlockedReason();
    if (blocked.length > 0) {
      this.showMessage(blocked, true);
      return;
    }

    let targets = this.targetStudentIds();
    this.publishing = true;
    this.message = '';
    try {
      let published = await this.viewModel.publish(
        this.result.generationId,
        this.publishScope,
        targets);
      if (published.targetStudentIds.length > 0) {
        this.onPublished();
      }
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

  private currentCandidateExists(): boolean {
    return this.candidate(this.viewModel.activeStudentId()) !== null;
  }

  private currentCandidateSummary(): string {
    let selectedCandidate = this.candidate(this.viewModel.activeStudentId());
    if (selectedCandidate === null) return '';
    return `将发布给：${selectedCandidate.studentName} · ${selectedCandidate.grade} · ${selectedCandidate.semester}`;
  }

  private currentCandidateCompatible(): boolean {
    let selectedCandidate = this.candidate(this.viewModel.activeStudentId());
    return selectedCandidate !== null && selectedCandidate.compatible;
  }

  private questionTypeLabel(type: PracticeQuestionType): string {
    if (type === PracticeQuestionType.SINGLE_CHOICE) return '单选题';
    if (type === PracticeQuestionType.FILL_BLANK) return '填空题';
    if (type === PracticeQuestionType.NUMBER) return '数字题';
    return '练习题';
  }

  @Builder
  private LoadingState() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(46)
        .height(46)
        .color(AppTheme.PRIMARY);

      Text('正在生成练习')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Text(`AI正在根据“${this.requirement}”生成并校验${this.questionCount}道题`)
        .width('100%')
        .constraintSize({ maxWidth: 480 })
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Column({ space: 8 }) {
        Text('正在完成')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
        Text('生成题目 · 检查答案 · 校验年级与难度')
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .constraintSize({ maxWidth: 480 })
      .padding(AppTheme.CARD_PADDING_COMPACT)
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20, bottom: 48 });
  }

  @Builder
  private ErrorState() {
    Column({ space: 10 }) {
      Text('这次没有生成成功')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(this.message.length > 0 ? this.message : 'AI出题暂时不可用，请重新生成或返回修改条件')
        .width('100%')
        .constraintSize({ maxWidth: 480 })
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20, bottom: 48 });
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
        if (this.currentCandidateExists()) {
          Text(this.currentCandidateSummary())
            .width('100%')
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontColor(this.currentCandidateCompatible() ? AppTheme.SUBTEXT : AppTheme.WARNING);
        }
      } else if (this.result !== null && this.publishScope === PracticePublishScope.SELECTED) {
        Column({ space: 7 }) {
          ForEach(this.result.audienceCandidates, (candidate: PracticeAudienceCandidate) => {
            Row({ space: 10 }) {
              Text(this.isStudentSelected(candidate.studentId) ? '✓' : '○')
                .fontSize(AppTheme.BODY_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(!candidate.compatible ? AppTheme.DISABLED :
                  this.isStudentSelected(candidate.studentId) ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
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
            .backgroundColor(this.isStudentSelected(candidate.studentId) && candidate.compatible ?
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
  private PreviewContent() {
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
      }
      .width('100%')
      .padding({ bottom: 8 });
    }
  }

  @Builder
  private BottomActionBar() {
    if (this.generating) {
      Button('正在生成练习…', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .enabled(false);
    } else if (this.result === null || this.result.paper === null) {
      Row({ space: 10 }) {
        Button('返回修改', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.onBack());

        Button('重新生成', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => { void this.generate(); });
      }
      .width('100%');
    } else {
      Row({ space: 10 }) {
        Button('重新生成', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .enabled(!this.publishing)
          .onClick(() => { void this.generate(); });

        Button(this.publishing ? '正在发布…' : `发布给${this.targetStudentIds().length}个学生`,
          { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.publishing ||
            this.publishBlockedReason().length > 0 ? AppTheme.DISABLED : AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.publishing && this.publishBlockedReason().length === 0)
          .onClick(() => { void this.publish(); });
      }
      .width('100%');
    }
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: this.generating ? '正在生成练习' : '练习预览',
          subtitle: `${this.viewModel.subjectLabel(this.subject)} · ${this.viewModel.difficultyLabel(this.difficulty)} · ${this.questionCount}题`,
          backAccessibilityText: '返回修改生成条件',
          onBack: () => this.onBack()
        });

        if (this.generating) {
          this.LoadingState();
        } else if (this.result === null || this.result.paper === null) {
          this.ErrorState();
        } else {
          Scroll() {
            this.PreviewContent();
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off);
        }

        Column() {
          this.BottomActionBar();
        }
        .width('100%')
        .padding({ top: 10, bottom: 14 });
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
