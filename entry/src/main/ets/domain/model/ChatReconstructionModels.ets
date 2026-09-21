import { ImportedMessage } from './ImportModels';

export enum ChatMessageContentKind {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE'
}

export interface ParsedChatMessage {
  sender: string;
  timeText: string;
  detectedMinuteOfDay: number;
  approxTimestampEpochMs: number;
  text: string;
  imageHash: string;
  contentKind: ChatMessageContentKind;
  relativePosition: number;
  sourceFrameEvidenceIds: string[];
  frameOrderNo: number;
  localOrderNo: number;
}

export interface ParsedChatFrame {
  frameEvidenceId: string;
  groupTitle: string;
  messages: ParsedChatMessage[];
  warnings: string[];
}

export interface ChatReconstructionOptions {
  targetStartMinuteOfDay: number;
}

export interface ChatReconstructionResult {
  groupTitle: string;
  messages: ImportedMessage[];
  timeBoundaryReached: boolean;
  earliestDetectedMinuteOfDay: number;
  earliestDetectedTime: string;
  warnings: string[];
}
