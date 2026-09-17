export enum AppRoute {
  STUDENT_ASSIGNMENT_DETAIL = 'student/assignment/detail',
  STUDENT_STUDY = 'student/study',
  PARENT_REVIEW = 'parent/review',
  PARENT_IMPORT = 'parent/import',
  PARENT_IMPORT_CONFIRMATION = 'parent/import/confirmation',
  PARENT_EXTRA_CREATE = 'parent/extra/create'
}

export class AssignmentRouteParam {
  assignmentId: string;

  constructor(assignmentId: string) {
    this.assignmentId = assignmentId;
  }
}

export class ParentImportRouteParam {
}

export class ParentImportConfirmationRouteParam {
}

export class ParentExtraCreateRouteParam {
}
