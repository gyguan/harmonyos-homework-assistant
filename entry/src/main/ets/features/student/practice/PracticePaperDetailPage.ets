import { AppTheme } from '../../../common/theme/AppTheme';
import {
  PracticePaper,
  PracticeSourceType,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { PracticePaperDetailViewModel } from './PracticePaperDetailViewModel';

@Component
export struct PracticePaperDetailPage {
  @Prop paperId: string = '';
  @Prop version: number = 1;
  @State private paper: PracticePaper | null = null;
  @State private loading: boolean = true;
  @State private starting: boolean = false;
  @State private errorMessage: string = '';
  onBack: () => void = () => {};
  onStarted: (attemptId: string) => void = (_attemptId: string) => {};
  private readonly viewModel: PracticePaperDetailViewModel = new PracticePaperDetailViewModel();

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      this.paper = await this.viewModel.getPaper(this.paperId, this.version);
      if (this.paper === null) this.errorMessage = '套卷不存在或已下架。';
    } catch {
      this.errorMessage = '套卷加载失败，请稍后重试。';
    } finally {
      this.loading = false;
    }
  }

  private async start(): Promise<void> {
    if (this.paper === null || this.starting) return;
    this.starting = true;
    this.errorMessage = '';
    try {
      let attempt = await this.viewModel.start(this.paper.id, this.paper.version);
      this.onStarted(attempt.id);
    } catch {
      this.errorMessage = '开始练习失败，请检查网络和家庭云端连接。';
    } finally {
      this.starting = false;
    }
  }

  private sourceLabel(): string {
    if (this.paper === null) return '';
    if (this.paper.sourceType === PracticeSourceType.PRESET) return '平台预置';
    if (this.paper.sourceType === PracticeSourceType.AI_GENERATED) return 'AI 生成';
    if (this.paper.sourceType === PracticeSourceType.PARENT_CREATED) return '家长创建';
    return '外部导入';
  }

  @Builder
  private MetricCard(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(label).fontSize(11).fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.TEXT)
          .width(AppTheme.MIN_TOUCH_TARGET)
          .height(AppTheme.MIN_TOUCH_TARGET)
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('返回练习')
          .onClick(() => this.onBack());
        Text('套卷详情')
          .fontSize(AppTheme.DEEP_PAGE_HEADER_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
      }
      .width('100%')
      .height(AppTheme.DEEP_PAGE_HEADER_HEIGHT)
      .padding({ left: 8, right: 16 });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 16 }) {
          if (this.paper !== null) {
            Column({ space: 8 }) {
              Text(this.paper.title)
                .width('100%')
                .fontSize(AppTheme.PAGE_TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT);
              Text(`${PracticeTaxonomy.gradeLabel(this.paper.grade)} · ${PracticeTaxonomy.subjectLabel(this.paper.subject)} · ${PracticeTaxonomy.difficultyLabel(this.paper.difficulty)}`)
                .width('100%')
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              Text(this.paper.description)
                .width('100%')
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            Row({ space: 10 }) {
              this.MetricCard(`${this.paper.questionCount}`, '题目');
              this.MetricCard(`${this.paper.estimatedMinutes} 分钟`, '预计');
              this.MetricCard(PracticeTaxonomy.difficultyLabel(this.paper.difficulty), '难度');
            }
            .width('100%');

            Column({ space: 8 }) {
              Text('训练内容')
                .width('100%')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text(this.paper.tags.join(' · '))
                .width('100%')
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              Text(`内容来源：${this.sourceLabel()} · 版本 V${this.paper.version}`)
                .width('100%')
                .fontSize(12)
                .fontColor(AppTheme.TERTIARY_TEXT);
            }
            .width('100%')
            .padding(AppTheme.CARD_PADDING)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.DANGER)
              .padding(12)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      if (this.paper !== null) {
        Row() {
          Button(this.starting ? '正在开始…' : '开始练习', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(this.starting ? AppTheme.DISABLED : AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .enabled(!this.starting)
            .onClick(() => void this.start());
        }
        .width('100%')
        .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 10, bottom: 14 })
        .backgroundColor(AppTheme.SURFACE)
        .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
