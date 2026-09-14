import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct ParentProgressPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  private submissions(assignmentId: string): Submission[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId);
  }

  @Builder
  private SubmissionPhotos(submission: Submission) {
    Column({ space: 8 }) {
      Text(`提交：${submission.fileLabel} · ${submission.submittedAtText}`)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUCCESS);

      Scroll() {
        Row({ space: 8 }) {
          ForEach(submission.photoUris, (uri: string) => {
            Image(uri)
              .width(82)
              .height(82)
              .objectFit(ImageFit.Cover)
              .borderRadius(9)
              .backgroundColor('#F1F3F5');
          }, (uri: string) => uri);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#EEF9F3')
    .borderRadius(10);
  }

  @Builder
  private ProgressCard(item: Assignment) {
    Column({ space: 9 }) {
      Row() {
        Text(item.subject).fontSize(12).fontColor(AppTheme.PRIMARY);
        Blank();
        Text(AssignmentStateMachine.label(item.status))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%');

      Text(item.title)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Text(item.dueText)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);

      if (this.submissions(item.id).length > 0) {
        this.SubmissionPhotos(this.submissions(item.id)[0]);
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(16)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('作业进度').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('今天做了什么、交了什么，一眼就能看到').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 16 }) {
            Column({ space: 12 }) {
              ForEach(this.assignments().slice(0, Math.ceil(this.assignments().length / 2)), (item: Assignment) => {
                this.ProgressCard(item);
              }, (item: Assignment) => item.id);
            }
            .layoutWeight(1);
            Column({ space: 12 }) {
              ForEach(this.assignments().slice(Math.ceil(this.assignments().length / 2)), (item: Assignment) => {
                this.ProgressCard(item);
              }, (item: Assignment) => item.id);
            }
            .layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          ForEach(this.assignments(), (item: Assignment) => {
            this.ProgressCard(item);
          }, (item: Assignment) => item.id);
        }
      }
      .width('100%')
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
