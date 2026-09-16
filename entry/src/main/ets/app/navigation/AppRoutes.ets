export enum AppRoute {
  STUDENT_ASSIGNMENT_DETAIL = 'student/assignment/detail',
  STUDENT_STUDY = 'student/study',
  PARENT_REVIEW = 'parent/review'
}

export class AssignmentRouteParam {
  assignmentId: string;

  constructor(assignmentId: string) {
    this.assignmentId = assignmentId;
  }
}
