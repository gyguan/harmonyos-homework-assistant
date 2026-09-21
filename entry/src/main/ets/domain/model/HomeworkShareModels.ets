export enum HomeworkShareRecordKind {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE'
}

export interface PendingHomeworkShareRecord {
  id: string;
  kind: HomeworkShareRecordKind;
  utd: string;
  content: string;
  sandboxUri: string;
  title: string;
}

export interface PendingHomeworkShareImport {
  token: string;
  createdAtEpochMs: number;
  records: PendingHomeworkShareRecord[];
}

export interface HomeworkShareImportProcessResult {
  batchId: string;
  candidateCount: number;
}
