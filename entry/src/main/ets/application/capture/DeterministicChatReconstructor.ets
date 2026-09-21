import {
  ChatReconstructionOptions,
  ChatReconstructionResult,
  ParsedChatFrame,
  ParsedChatMessage
} from '../../domain/model/ChatReconstructionModels';
import { CaptureFrameEvidence } from '../../domain/model/CaptureModels';
import {
  HomeworkImportSourceType,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { DeterministicChatRegionParser } from './DeterministicChatRegionParser';

interface ChatNode {
  message: ParsedChatMessage;
  sourceFrameEvidenceIds: string[];
}

interface OverlapMatch {
  existingStart: number;
  frameStart: number;
  length: number;
}

export class DeterministicChatReconstructor {
  private readonly parser: DeterministicChatRegionParser = new DeterministicChatRegionParser();

  reconstruct(batchId: string, evidence: CaptureFrameEvidence[],
    options: ChatReconstructionOptions): ChatReconstructionResult {
    let frames: ParsedChatFrame[] = [];
    let warnings: string[] = [];
    let groupTitles: string[] = [];

    let orderedEvidence: CaptureFrameEvidence[] = [];
    for (let item of evidence) orderedEvidence.push(item);
    orderedEvidence.sort((left: CaptureFrameEvidence, right: CaptureFrameEvidence) =>
      left.orderNo - right.orderNo);

    for (let item of orderedEvidence) {
      let parsed = this.parser.parse(item);
      frames.push(parsed);
      if (parsed.groupTitle.length > 0) groupTitles.push(parsed.groupTitle);
      for (let warning of parsed.warnings) this.addWarning(warnings, warning);
    }

    let nodes: ChatNode[] = [];
    for (let frame of frames) {
      if (frame.messages.length === 0) {
        this.addWarning(warnings, `FRAME_${frame.frameEvidenceId}_OCR_EMPTY_OR_UNPARSED`);
        continue;
      }
      if (nodes.length === 0) {
        for (let message of frame.messages) nodes.push(this.newNode(message));
        continue;
      }
      this.mergeFrame(nodes, frame, warnings);
    }

    if (this.allMessagesTimed(nodes)) {
      nodes.sort((left: ChatNode, right: ChatNode) => {
        if (left.message.detectedMinuteOfDay !== right.message.detectedMinuteOfDay) {
          return left.message.detectedMinuteOfDay - right.message.detectedMinuteOfDay;
        }
        if (left.message.frameOrderNo !== right.message.frameOrderNo) {
          return left.message.frameOrderNo - right.message.frameOrderNo;
        }
        return left.message.localOrderNo - right.message.localOrderNo;
      });
    }

    let messages: ImportedMessage[] = [];
    let earliestMinute = -1;
    let earliestText = '';
    for (let i = 0; i < nodes.length; i++) {
      let node = nodes[i];
      let messageId = `${batchId}-chat-${i + 1}`;
      let minute = node.message.detectedMinuteOfDay;
      if (minute >= 0 && (earliestMinute < 0 || minute < earliestMinute)) {
        earliestMinute = minute;
        earliestText = node.message.timeText;
      }
      messages.push({
        id: messageId,
        batchId: batchId,
        sender: node.message.sender,
        timestampEpochMs: node.message.approxTimestampEpochMs,
        text: node.message.text,
        attachments: [],
        sourceEvidence: {
          sourceType: HomeworkImportSourceType.SCREEN_CAPTURE,
          sourceMessageIds: [messageId],
          sourceFrameEvidenceIds: node.sourceFrameEvidenceIds.slice(),
          rawText: node.message.text,
          imageRef: '',
          capturedAtEpochMs: node.message.approxTimestampEpochMs
        },
        fingerprint: this.persistedFingerprint(node.message),
        orderNo: i + 1
      });
    }

    let groupTitle = this.resolveGroupTitle(groupTitles, warnings);
    let boundary = options.targetStartMinuteOfDay >= 0 &&
      earliestMinute >= 0 && earliestMinute < options.targetStartMinuteOfDay;
    return {
      groupTitle: groupTitle,
      messages: messages,
      timeBoundaryReached: boundary,
      earliestDetectedMinuteOfDay: earliestMinute,
      earliestDetectedTime: earliestText,
      warnings: warnings
    };
  }

  private mergeFrame(nodes: ChatNode[], frame: ParsedChatFrame, warnings: string[]): void {
    let overlap = this.bestOverlap(nodes, frame.messages);
    if (overlap.length > 0) {
      for (let i = 0; i < overlap.length; i++) {
        let node = nodes[overlap.existingStart + i];
        let incoming = frame.messages[overlap.frameStart + i];
        this.mergeMessage(node, incoming);
      }

      let before: ParsedChatMessage[] = [];
      for (let i = 0; i < overlap.frameStart; i++) before.push(frame.messages[i]);
      let after: ParsedChatMessage[] = [];
      for (let i = overlap.frameStart + overlap.length; i < frame.messages.length; i++) {
        after.push(frame.messages[i]);
      }

      let beforeNodes = this.newDistinctNodes(nodes, before);
      if (beforeNodes.length > 0) {
        nodes.splice(overlap.existingStart, 0, ...beforeNodes);
      }

      let overlapEnd = overlap.existingStart + beforeNodes.length + overlap.length;
      let afterNodes = this.newDistinctNodes(nodes, after);
      if (afterNodes.length > 0) {
        nodes.splice(overlapEnd, 0, ...afterNodes);
      }
      return;
    }

    let additions = this.newDistinctNodes(nodes, frame.messages);
    if (additions.length === 0) return;

    let frameRange = this.knownTimeRange(additions);
    let existingRange = this.knownTimeRange(nodes);
    if (frameRange[1] >= 0 && existingRange[0] >= 0 && frameRange[1] < existingRange[0]) {
      nodes.splice(0, 0, ...additions);
      return;
    }
    if (frameRange[0] >= 0 && existingRange[1] >= 0 && frameRange[0] > existingRange[1]) {
      for (let item of additions) nodes.push(item);
      return;
    }

    for (let item of additions) nodes.push(item);
    this.addWarning(warnings, `FRAME_${frame.frameEvidenceId}_NO_CONFIDENT_OVERLAP`);
  }

  private bestOverlap(nodes: ChatNode[], incoming: ParsedChatMessage[]): OverlapMatch {
    let best: OverlapMatch = { existingStart: 0, frameStart: 0, length: 0 };
    for (let existingStart = 0; existingStart < nodes.length; existingStart++) {
      for (let frameStart = 0; frameStart < incoming.length; frameStart++) {
        let length = 0;
        while (existingStart + length < nodes.length &&
          frameStart + length < incoming.length &&
          this.baseMatch(nodes[existingStart + length].message, incoming[frameStart + length])) {
          length++;
        }
        if (length < best.length) continue;
        if (length === 1 && !this.strongIdentity(
          nodes[existingStart].message, incoming[frameStart])) continue;
        if (length > best.length) {
          best = {
            existingStart: existingStart,
            frameStart: frameStart,
            length: length
          };
        }
      }
    }
    return best;
  }

  private newDistinctNodes(existing: ChatNode[], messages: ParsedChatMessage[]): ChatNode[] {
    let result: ChatNode[] = [];
    for (let message of messages) {
      let duplicate = this.findStrongDuplicate(existing, message);
      if (duplicate !== null) {
        this.mergeMessage(duplicate, message);
        continue;
      }
      let duplicateInResult = this.findStrongDuplicate(result, message);
      if (duplicateInResult !== null) {
        this.mergeMessage(duplicateInResult, message);
        continue;
      }
      result.push(this.newNode(message));
    }
    return result;
  }

  private findStrongDuplicate(nodes: ChatNode[], message: ParsedChatMessage): ChatNode | null {
    for (let node of nodes) {
      if (this.strongIdentity(node.message, message)) return node;
    }
    return null;
  }

  private baseMatch(left: ParsedChatMessage, right: ParsedChatMessage): boolean {
    if (this.normalized(left.sender) !== this.normalized(right.sender)) return false;
    if (this.normalized(left.text) !== this.normalized(right.text)) return false;
    if (left.imageHash !== right.imageHash) return false;
    if (left.detectedMinuteOfDay >= 0 && right.detectedMinuteOfDay >= 0 &&
      left.detectedMinuteOfDay !== right.detectedMinuteOfDay) return false;
    return true;
  }

  private strongIdentity(left: ParsedChatMessage, right: ParsedChatMessage): boolean {
    if (!this.baseMatch(left, right)) return false;
    if (left.detectedMinuteOfDay >= 0 && right.detectedMinuteOfDay >= 0) return true;
    return left.imageHash.length > 0 && right.imageHash.length > 0;
  }

  private mergeMessage(node: ChatNode, incoming: ParsedChatMessage): void {
    for (let frameId of incoming.sourceFrameEvidenceIds) {
      if (node.sourceFrameEvidenceIds.indexOf(frameId) < 0) node.sourceFrameEvidenceIds.push(frameId);
    }
    if (node.message.sender.length === 0 && incoming.sender.length > 0) node.message.sender = incoming.sender;
    if (node.message.detectedMinuteOfDay < 0 && incoming.detectedMinuteOfDay >= 0) {
      node.message.detectedMinuteOfDay = incoming.detectedMinuteOfDay;
      node.message.timeText = incoming.timeText;
      node.message.approxTimestampEpochMs = incoming.approxTimestampEpochMs;
    }
  }

  private newNode(message: ParsedChatMessage): ChatNode {
    return {
      message: {
        sender: message.sender,
        timeText: message.timeText,
        detectedMinuteOfDay: message.detectedMinuteOfDay,
        approxTimestampEpochMs: message.approxTimestampEpochMs,
        text: message.text,
        imageHash: message.imageHash,
        contentKind: message.contentKind,
        relativePosition: message.relativePosition,
        sourceFrameEvidenceIds: message.sourceFrameEvidenceIds.slice(),
        frameOrderNo: message.frameOrderNo,
        localOrderNo: message.localOrderNo
      },
      sourceFrameEvidenceIds: message.sourceFrameEvidenceIds.slice()
    };
  }

  private knownTimeRange(nodes: ChatNode[]): number[] {
    let min = -1;
    let max = -1;
    for (let node of nodes) {
      let value = node.message.detectedMinuteOfDay;
      if (value < 0) continue;
      if (min < 0 || value < min) min = value;
      if (max < 0 || value > max) max = value;
    }
    return [min, max];
  }

  private allMessagesTimed(nodes: ChatNode[]): boolean {
    if (nodes.length === 0) return false;
    for (let node of nodes) if (node.message.detectedMinuteOfDay < 0) return false;
    return true;
  }

  private resolveGroupTitle(values: string[], warnings: string[]): string {
    if (values.length === 0) return '';
    let best = '';
    let bestCount = 0;
    for (let value of values) {
      let count = 0;
      for (let candidate of values) if (candidate === value) count++;
      if (count > bestCount) {
        best = value;
        bestCount = count;
      }
    }
    for (let value of values) {
      if (value !== best) {
        this.addWarning(warnings, 'GROUP_TITLE_CONFLICT');
        break;
      }
    }
    return best;
  }

  private persistedFingerprint(message: ParsedChatMessage): string {
    let time = message.detectedMinuteOfDay >= 0 ? `${message.detectedMinuteOfDay}` : '?';
    let positionBucket = Math.floor(message.relativePosition / 100);
    return [
      this.normalized(message.text),
      this.normalized(message.sender),
      time,
      message.imageHash,
      `pos${positionBucket}`
    ].join('|');
  }

  private normalized(value: string): string {
    return value.trim().replace(/\s+/g, ' ').toLowerCase();
  }

  private addWarning(warnings: string[], warning: string): void {
    if (warnings.indexOf(warning) < 0) warnings.push(warning);
  }
}
