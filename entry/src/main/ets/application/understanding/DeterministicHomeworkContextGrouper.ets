import {
  ClassifiedHomeworkMessage,
  HomeworkMessageClassification,
  HomeworkMessageGroup,
  TeacherResolutionStatus
} from '../../domain/model/HomeworkUnderstandingModels';
import { Subject } from '../../domain/model/HomeworkModels';

export class DeterministicHomeworkContextGrouper {
  group(messages: ClassifiedHomeworkMessage[]): HomeworkMessageGroup[] {
    let groups: HomeworkMessageGroup[] = [];
    for (let item of messages) {
      if (item.teacher.status !== TeacherResolutionStatus.RESOLVED || item.teacher.subject === null) continue;
      if (item.classification === HomeworkMessageClassification.CHAT ||
        item.classification === HomeworkMessageClassification.NOTICE ||
        item.classification === HomeworkMessageClassification.UNKNOWN) continue;

      let group = this.findGroup(groups, item.teacher.teacherId, item.teacher.subject);
      if (group === null) {
        group = {
          subject: item.teacher.subject,
          teacherId: item.teacher.teacherId,
          teacherName: item.teacher.displayName,
          messages: []
        };
        groups.push(group);
      }
      group.messages.push(item);
    }
    return groups;
  }

  private findGroup(groups: HomeworkMessageGroup[], teacherId: string,
    subject: Subject): HomeworkMessageGroup | null {
    for (let group of groups) {
      if (group.teacherId === teacherId && group.subject === subject) return group;
    }
    return null;
  }
}
