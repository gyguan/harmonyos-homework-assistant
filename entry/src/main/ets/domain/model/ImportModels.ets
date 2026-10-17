import { CandidateAssignment } from './HomeworkModels';

export enum HomeworkImageRecognitionMode {
  AI_IMAGE = 'AI_IMAGE',
  OCR = 'OCR'
}

export enum HomeworkOrganizerMode {
  AI = 'AI',
  LOCAL = 'LOCAL'
}

export enum HomeworkImportSourceType {
  CLIPBOARD = 'CLIPBOARD',
  SCREENSHOT = 'SCREENSHOT',
  SHARE = 'SHARE',
}

export enum ImportBatchStatus {
  RECEIVED = 'RECEIVED',
  READY = 'READY',
  EMPTY = 'EMPTY',
  PUBLISHED = 'PUBLISHED',
  ABANDONED = 'ABANDONED'
}

export enum HomeworkImportPipelineStage {
  CAPTURED = 'CAPTURED',
  UNDERSTOOD = 'UNDERSTOOD',
  ACTIVATED = 'ACTIVATED',
  UNDERSTANDING_FAILED = 'UNDERSTANDING_FAILED'
}

export interface ImportSourceEvidence {
  sourceType: HomeworkImportSourceType;
  sourceMessageIds: string[];
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
  pipelineStage?: HomeworkImportPipelineStage;
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
  /** 已连接云端但 AI 整理失败（已回退本地规则），需要向用户提示。 */
  aiFailed: boolean;
}

export interface HomeworkTextImportResult {
  candidateCount: number;
  organizerMode: HomeworkOrganizerMode;
  /** 已连接云端但 AI 整理失败（已回退本地规则），需要向用户提示。 */
  aiFailed: boolean;
}

export interface HomeworkImageImportResult {
  selected: boolean;
  candidateCount: number;
  recognizedText: string;
  organizerMode: HomeworkOrganizerMode;
  /** 已连接云端但 AI 整理失败（已回退本地规则），需要向用户提示。 */
  aiFailed: boolean;
}

export interface HomeworkImageTextResult {
  selected: boolean;
  recognizedText: string;
  imageRef: string;
}
