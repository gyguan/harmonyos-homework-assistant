export enum AppRoute {
  STUDENT_ASSIGNMENT_DETAIL = 'student/assignment/detail',
  STUDENT_STUDY = 'student/study',
  STUDENT_PRACTICE_PAPER = 'student/practice/paper',
  STUDENT_PRACTICE_ATTEMPT = 'student/practice/attempt',
  STUDENT_PRACTICE_RESULT = 'student/practice/result',
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

export class PracticePaperRouteParam {
  paperId: string;
  version: number;

  constructor(paperId: string, version: number) {
    this.paperId = paperId;
    this.version = version;
  }
}

export class PracticeAttemptRouteParam {
  attemptId: string;

  constructor(attemptId: string) {
    this.attemptId = attemptId;
  }
}

export class ParentImportRouteParam {
}

export class ParentImportConfirmationRouteParam {
}

export class ParentExtraCreateRouteParam {
  voice: boolean;

  constructor(voice: boolean = false) {
    this.voice = voice;
  }
}
