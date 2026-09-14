import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct StudyWorkspacePage {
  @Prop sizeClass: WindowSizeClass;
  @Prop tutorUnavailable: boolean = false;
  @Prop assignmentId: string = 'a-math-001';
  @Prop revision: number = 0;
  @State private compactTutorOpen: boolean = false;
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private assignment(): Assignment | null {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignment(this.assignmentId);
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getTodayAssignments();
  }

  private submissions(): Submission[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getSubmissionsForAssignment(this.assignmentId);
  }

  private primaryActionLabel(): string {
    let assignment = this.assignment();
    if (assignment === null) {
      return '作业不存在';
    }
    switch (assignment.status) {
      case AssignmentStatus.NOT_STARTED:
      case AssignmentStatus.OVERDUE:
      case AssignmentStatus.NEEDS_REWORK:
        return '开始作业';
      case AssignmentStatus.IN_PROGRESS:
        return '我做完了，准备提交';
      case AssignmentStatus.READY_TO_SUBMIT:
        return '模拟拍照提交';
      case AssignmentStatus.SUBMITTED:
        return '已提交';
      case AssignmentStatus.COMPLETED:
        return '已完成';
      default:
        return '继续';
    }
  }

  private primaryActionEnabled(): boolean {
    let assignment = this.assignment();
    if (assignment === null) {
      return false;
    }
    return assignment.status !== AssignmentStatus.SUBMITTED && assignment.status !== AssignmentStatus.COMPLETED;
  }

  private runPrimaryAction(): void {
    let assignment = this.assignment();
    if (assignment === null) {
      return;
    }
    let changed: boolean = false;
    if (assignment.status === AssignmentStatus.NOT_STARTED ||
      assignment.status === AssignmentStatus.OVERDUE ||
      assignment.status === AssignmentStatus.NEEDS_REWORK) {
      changed = HomeworkStore.instance.startAssignment(assignment.id);
    } else if (assignment.status === AssignmentStatus.IN_PROGRESS) {
      changed = HomeworkStore.instance.markReadyToSubmit(assignment.id);
    } else if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      changed = HomeworkStore.instance.submitMockImage(assignment.id);
    }
    if (changed) {
      this.onStoreChanged();
    }
  }

  @Builder
  private TaskRail() {
    Column({ space: 10 }) {
      Text('今天').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private StudyContent() {
    if (this.assignment() === null) {
      Column({ space: 10 }) {
        Text('找不到这项作业').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text('请返回今日作业重新进入。').fontSize(14).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(18);
    } else {
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Text(`${this.assignment()!.subject} · ${AssignmentStateMachine.label(this.assignment()!.status)}`)
              .fontSize(13)
              .fontColor(AppTheme.PRIMARY);
            Blank();
            Text(this.assignment()!.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          Text(this.assignment()!.title)
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(this.assignment()!.instruction)
            .width('100%')
            .fontSize(15)
            .fontColor(AppTheme.SUBTEXT);

          Column({ space: 8 }) {
            if (this.assignment()!.resourceLabels.length === 0) {
              Text('暂无老师附件').width('100%').fontSize(14).fontColor(AppTheme.SUBTEXT);
            } else {
              ForEach(this.assignment()!.resourceLabels, (label: string) => {
                Text(label).width('100%').fontSize(15);
              }, (label: string) => label);
            }
            Text('📘 ' + this.assignment()!.textbookRef)
              .width('100%')
              .fontSize(14)
              .fontColor(AppTheme.PRIMARY);
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor('#F4F6F9');

          if (this.submissions().length > 0) {
            Text(`已保存提交：${this.submissions()[0].fileLabel} · ${this.submissions()[0].submittedAtText}`)
              .width('100%')
              .padding(12)
              .fontSize(13)
              .fontColor(AppTheme.SUCCESS)
              .backgroundColor('#EEF9F3')
              .borderRadius(12);
          }

          Button(this.primaryActionLabel())
            .width('100%')
            .height(48)
            .enabled(this.primaryActionEnabled())
            .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : '#C9D1DD')
            .onClick(() => this.runPrimaryAction());
        }
        .width('100%');
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private TutorPane() {
    Column({ space: 12 }) {
      Text('问小伴')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);

      if (this.tutorUnavailable) {
        Text('AI 辅导暂时不可用')
          .width('100%')
          .padding(14)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.WARNING)
          .backgroundColor('#FFF8E7')
          .borderRadius(14);
        Text('你仍然可以查看老师资料、完成作业并提交。联网或服务恢复后再继续问小伴。')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      } else {
        Text('你现在卡在哪一道题？可以拍给我看，也可以直接说。')
          .width('100%')
          .padding(14)
          .fontSize(14)
          .fontColor(AppTheme.TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(14);
        Text('提示策略：先给一点提示，不直接说答案。')
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '输入问题…' })
          .width('100%')
          .height(44)
          .backgroundColor('#F7F8FA');
        Row({ space: 8 }) {
          Button('🎙 语音').layoutWeight(1);
          Button('📷 拍题').layoutWeight(1);
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CompactWorkspace() {
    if (this.compactTutorOpen) {
      Column({ space: 12 }) {
        Text('‹ 返回作业')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.compactTutorOpen = false);
        this.TutorPane();
      }
      .width('100%')
      .layoutWeight(1);
    } else {
      Column({ space: 12 }) {
        Column() {
          this.StudyContent();
        }
        .width('100%')
        .layoutWeight(1);

        Button('问小伴')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.compactTutorOpen = true);
      }
      .width('100%')
      .layoutWeight(1);
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.onBack());
        Blank();
        if (this.assignment() !== null) {
          Text(this.assignment()!.dueText).fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.sizeClass === WindowSizeClass.EXPANDED) {
        Row({ space: 14 }) {
          Column() { this.TaskRail(); }.width('20%');
          Column() { this.StudyContent(); }.width('50%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else if (this.sizeClass === WindowSizeClass.MEDIUM) {
        Row({ space: 14 }) {
          Column() { this.StudyContent(); }.width('64%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else {
        this.CompactWorkspace();
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
