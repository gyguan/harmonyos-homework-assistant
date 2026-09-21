import { CandidateAssignment } from './HomeworkModels';

export enum HomeworkOrganizerMode {
  AI = 'AI',
  LOCAL = 'LOCAL'
}

export enum HomeworkImportSourceType {
  CLIPBOARD = 'CLIPBOARD',
  SCREENSHOT = 'SCREENSHOT',
  SHARE = 'SHARE',
  SCREEN_CAPTURE = 'SCREEN_CAPTURE'
}

export enum ImportBatchStatus {
  RECEIVED = 'RECEIVED',
  READY = 'READY',
  EMPTY = 'EMPTY',
  PUBLISHED = 'PUBLISHED',
  ABANDONED = 'ABANDONED'
}

export interface ImportSourceEvidence {
  sourceType: HomeworkImportSourceType;
  sourceMessageIds: string[];
  sourceFrameEvidenceIds?: string[];
  rawText: string;
  imageRef: string;
  capturedAtEpochMs: number;
}

export interface ImportedMessage {
  id: string;
  batchId: string;
  sender: string;
  timestampEpochMs: number;
  text: string;
  attachments: string[];
  sourceEvidence: ImportSourceEvidence;
  fingerprint: string;
  orderNo: number;
}

export interface ImportBatch {
  id: string;
  studentId: string;
  sourceType: HomeworkImportSourceType;
  sourceLabel: string;
  sourceProfileId: string;
  captureSessionId?: string;
  reconstructed?: boolean;
  groupTitle?: string;
  timeBoundaryReached?: boolean;
  earliestDetectedTime?: string;
  reconstructionWarnings?: string[];
  understood?: boolean;
  understandingVersion?: string;
  pendingReviewMessageIds?: string[];
  understandingWarnings?: string[];
  classificationSummary?: string;
  createdAtEpochMs: number;
  status: ImportBatchStatus;
  messageCount: number;
  candidateCount: number;
}

export interface HomeworkImportInboxSnapshot {
  schemaVersion: number;
  activeBatchId: string;
  batches: ImportBatch[];
  messages: ImportedMessage[];
  candidates: CandidateAssignment[];
}

export interface ExtractedHomeworkText {
  importId: string;
  studentId: string;
  sourceLabel: string;
  text: string;
}

export interface HomeworkImportPipelineResult {
  extracted: ExtractedHomeworkText;
  candidates: CandidateAssignment[];
  organizerMode: HomeworkOrganizerMode;
}

export interface HomeworkTextImportResult {
  candidateCount: number;
  organizerMode: HomeworkOrganizerMode;
}

export interface HomeworkImageImportResult {
  selected: boolean;
  candidateCount: number;
  recognizedText: string;
  organizerMode: HomeworkOrganizerMode;
}
