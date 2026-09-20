import { AppTheme } from '../../../common/theme/AppTheme';
import { ChoiceSelectionChip } from '../../../components/selection/SelectionControls';
import {
  PracticeGrade,
  PracticePaper,
  PracticeSubject,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { PracticeHomeViewModel } from './PracticeHomeViewModel';

@Component
struct PracticePaperCard {
  @Prop paper: PracticePaper;
  @Prop difficultyLabel: string = '';

  private tagsText(): string {
    return this.paper.tags.join(' · ');
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(this.paper.title)
            .width('100%')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(`${PracticeTaxonomy.gradeLabel(this.paper.grade)} · ${PracticeTaxonomy.subjectLabel(this.paper.subject)} · ${this.difficultyLabel}`)
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(`${this.paper.questionCount} 题`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Text(this.paper.description)
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(AppTheme.SUBTEXT);

      Row({ space: 8 }) {
        Text(`约 ${this.paper.estimatedMinutes} 分钟`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
        Text(this.tagsText())
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
        Text('预置题库')
          .fontSize(11)
          .fontColor(AppTheme.SUCCESS);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }
}

@Component
export struct PracticeHomePage {
  @Prop revision: number = 0;
  @State private selectedGrade: PracticeGrade = PracticeGrade.G3;
  @State private selectedSubject: PracticeSubject = PracticeSubject.MATH;
  @State private papers: PracticePaper[] = [];
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  private loadSequence: number = 0;
  private readonly viewModel: PracticeHomeViewModel = new PracticeHomeViewModel();

  aboutToAppear(): void {
    this.selectedGrade = this.viewModel.defaultGrade();
    void this.reloadPapers();
  }

  private async reloadPapers(): Promise<void> {
    let sequence = ++this.loadSequence;
    this.loading = true;
    this.errorMessage = '';
    try {
      let papers = await this.viewModel.listPapers(this.selectedGrade, this.selectedSubject);
      if (sequence !== this.loadSequence) return;
      this.papers = papers;
    } catch {
      if (sequence !== this.loadSequence) return;
      this.papers = [];
      this.errorMessage = '套卷加载失败，请稍后重试。';
    } finally {
      if (sequence === this.loadSequence) this.loading = false;
    }
  }

  private selectGrade(grade: PracticeGrade): void {
    if (grade === this.selectedGrade) return;
    this.selectedGrade = grade;
    void this.reloadPapers();
  }

  private selectSubject(subject: PracticeSubject): void {
    if (subject === this.selectedSubject) return;
    this.selectedSubject = subject;
    void this.reloadPapers();
  }

  @Builder
  private GradeSelector() {
    Column({ space: 8 }) {
      Text('年级')
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.SUBTEXT);
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.viewModel.grades(), (grade: PracticeGrade) => {
            ChoiceSelectionChip({
              label: this.viewModel.gradeLabel(grade),
              selected: this.selectedGrade === grade,
              compact: true,
              onSelect: () => this.selectGrade(grade)
            });
          }, (grade: PracticeGrade) => grade);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }

  @Builder
  private SubjectSelector() {
    Column({ space: 8 }) {
      Text('科目')
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        ForEach(this.viewModel.subjects(), (subject: PracticeSubject) => {
          ChoiceSelectionChip({
            label: this.viewModel.subjectLabel(subject),
            selected: this.selectedSubject === subject,
            onSelect: () => this.selectSubject(subject)
          });
        }, (subject: PracticeSubject) => subject);
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private PaperList() {
    Column({ space: 10 }) {
      Row() {
        Text(`${this.viewModel.gradeLabel(this.selectedGrade)} · ${this.viewModel.subjectLabel(this.selectedSubject)}`)
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(this.loading ? '加载中…' : `${this.papers.length} 套`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.DANGER)
          .padding(14)
          .backgroundColor(AppTheme.DANGER_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else if (!this.loading && this.papers.length === 0) {
        Column({ space: 7 }) {
          Text('这个分类暂时没有套卷')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('可以切换年级或科目继续浏览。')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding({ top: 28, bottom: 28 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      } else {
        Column({ space: 9 }) {
          ForEach(this.papers, (paper: PracticePaper) => {
            PracticePaperCard({
              paper: paper,
              difficultyLabel: this.viewModel.difficultyLabel(paper)
            });
          }, (paper: PracticePaper) => `${paper.id}@${paper.version}`);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 18 }) {
          Column({ space: 5 }) {
            Text('练习')
              .width('100%')
              .fontSize(AppTheme.PAGE_TITLE_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
            Text('按年级和科目选择一套卷，反复练习并保留每次学习记录。')
              .width('100%')
              .fontSize(13)
              .lineHeight(19)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Column({ space: 14 }) {
            this.GradeSelector();
            Divider().color(AppTheme.DIVIDER);
            this.SubjectSelector();
          }
          .width('100%')
          .padding(AppTheme.PHONE_CARD_PADDING)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.PHONE_CARD_RADIUS);

          this.PaperList();

          Text('当前先提供预置套卷浏览；套卷作答、历史练习与错题重练将在后续 Slice 接入。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.TERTIARY_TEXT)
            .padding({ left: 2, right: 2, bottom: 8 });
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PRACTICE_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
