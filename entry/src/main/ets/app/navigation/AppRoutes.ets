export enum AppRoute {
  STUDENT_ASSIGNMENT_DETAIL = 'student/assignment/detail',
  STUDENT_STUDY = 'student/study',
  STUDENT_PRACTICE_HISTORY = 'student/practice/history',
  STUDENT_PRACTICE_PAPER = 'student/practice/paper',
  STUDENT_PRACTICE_ATTEMPT = 'student/practice/attempt',
  STUDENT_PRACTICE_RESULT = 'student/practice/result',
  PARENT_REVIEW = 'parent/review',
  PARENT_IMPORT = 'parent/import',
  PARENT_CAPTURE_HOME = 'parent/capture/home',
  PARENT_IMPORT_INBOX = 'parent/import/inbox',
  PARENT_IMPORT_BATCH_DETAIL = 'parent/import/inbox/detail',
  PARENT_CAPTURE = 'parent/import/capture',
  PARENT_SOURCE_PROFILE = 'parent/import/source-profile',
  PARENT_CAPTURE_DIAGNOSTIC = 'parent/capture/diagnostic',
  PARENT_IMPORT_CONFIRMATION = 'parent/import/confirmation',
  PARENT_EXTRA_CREATE = 'parent/extra/create'
}

export class AssignmentRouteParam {
  assignmentId: string;

  constructor(assignmentId: string) {
    this.assignmentId = assignmentId;
  }
}

export class PracticeHistoryRouteParam {
  paperId: string;

  constructor(paperId: string = '') {
    this.paperId = paperId;
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

export class ParentCaptureHomeRouteParam {
}

export class ParentImportInboxRouteParam {
}

export class ParentImportBatchRouteParam {
  batchId: string;

  constructor(batchId: string) {
    this.batchId = batchId;
  }
}

export class ParentCaptureRouteParam {
}

export class ParentSourceProfileRouteParam {
  startCaptureAfterSave: boolean;

  constructor(startCaptureAfterSave: boolean = false) {
    this.startCaptureAfterSave = startCaptureAfterSave;
  }
}

export class ParentCaptureDiagnosticRouteParam {
}

export class ParentImportConfirmationRouteParam {
}

export class ParentExtraCreateRouteParam {
  voice: boolean;

  constructor(voice: boolean = false) {
    this.voice = voice;
  }
}
