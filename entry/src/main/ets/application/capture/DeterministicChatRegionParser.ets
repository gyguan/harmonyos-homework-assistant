import {
  CaptureFrameEvidence,
  CaptureOcrLineEvidence
} from '../../domain/model/CaptureModels';
import {
  ChatMessageContentKind,
  ParsedChatFrame,
  ParsedChatMessage
} from '../../domain/model/ChatReconstructionModels';

interface DetectedTime {
  text: string;
  minuteOfDay: number;
  dayOffset: number;
}

export class DeterministicChatRegionParser {
  parse(frame: CaptureFrameEvidence): ParsedChatFrame {
    let lines: CaptureOcrLineEvidence[] = [];
    let sourceLines = frame.lines === undefined ? [] : frame.lines;
    for (let source of sourceLines) {
      let value = this.normalizeText(source.value);
      if (value.length === 0) continue;
      lines.push({
        value: value,
        left: source.left,
        top: source.top,
        right: source.right,
        bottom: source.bottom
      });
    }
    lines.sort((left: CaptureOcrLineEvidence, right: CaptureOcrLineEvidence) => {
      if (left.top !== right.top) return left.top - right.top;
      return left.left - right.left;
    });

    let groupTitle = this.detectGroupTitle(lines, frame.width, frame.height);
    let messages: ParsedChatMessage[] = [];
    let warnings: string[] = [];
    let pendingTime: DetectedTime | null = null;
    let pendingSender = '';

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];
      if (groupTitle.length > 0 && line.value === groupTitle && this.isHeaderLine(line, frame.height)) continue;

      let inline = this.parseInlineMessage(line.value, frame.capturedAtEpochMs);
      if (inline !== null) {
        inline.relativePosition = this.relativePosition(line, frame.height);
        inline.sourceFrameEvidenceIds = [frame.id];
        inline.frameOrderNo = frame.orderNo;
        inline.localOrderNo = messages.length + 1;
        messages.push(inline);
        pendingSender = '';
        pendingTime = null;
        continue;
      }

      let detectedTime = this.parseTime(line.value);
      if (detectedTime !== null && this.isStandaloneTime(line.value)) {
        pendingTime = detectedTime;
        pendingSender = '';
        continue;
      }

      if (this.looksLikeSender(lines, i)) {
        pendingSender = this.senderFromLine(line.value);
        continue;
      }

      let imageHash = this.imageHash(line.value);
      let kind = imageHash.length > 0 || this.isImagePlaceholder(line.value) ?
        ChatMessageContentKind.IMAGE : ChatMessageContentKind.TEXT;
      let time = pendingTime;
      let parsed: ParsedChatMessage = {
        sender: pendingSender,
        timeText: time === null ? '' : time.text,
        detectedMinuteOfDay: time === null ? -1 : time.minuteOfDay,
        approxTimestampEpochMs: time === null ? 0 :
          this.approxEpoch(frame.capturedAtEpochMs, time.minuteOfDay, time.dayOffset),
        text: line.value,
        imageHash: imageHash,
        contentKind: kind,
        relativePosition: this.relativePosition(line, frame.height),
        sourceFrameEvidenceIds: [frame.id],
        frameOrderNo: frame.orderNo,
        localOrderNo: messages.length + 1
      };
      messages.push(parsed);
      pendingSender = '';
      // A visible WeChat timestamp is an approximate anchor for following messages until
      // another explicit timestamp appears, so keep pendingTime rather than clearing it.
    }

    if (messages.length === 0 && frame.text.trim().length > 0) {
      warnings.push(`FRAME_${frame.orderNo}_NO_MESSAGE_BLOCK`);
    }
    return {
      frameEvidenceId: frame.id,
      groupTitle: groupTitle,
      messages: messages,
      warnings: warnings
    };
  }

  private detectGroupTitle(lines: CaptureOcrLineEvidence[], width: number, height: number): string {
    for (let line of lines) {
      if (!this.isHeaderLine(line, height)) continue;
      if (this.parseTime(line.value) !== null) continue;
      if (line.value.length > 40) continue;
      let center = (line.left + line.right) / 2;
      if (width > 0 && Math.abs(center - width / 2) > width * 0.28) continue;
      return line.value;
    }
    return '';
  }

  private isHeaderLine(line: CaptureOcrLineEvidence, height: number): boolean {
    if (height <= 0) return line.top < 160;
    return line.top <= height * 0.16;
  }

  private parseInlineMessage(value: string, capturedAtEpochMs: number): ParsedChatMessage | null {
    let timeFirst = value.match(/^((?:昨天\s*)?(?:[01]?\d|2[0-3]):[0-5]\d)\s+([^\s]{1,20})\s+(.+)$/);
    if (timeFirst !== null) {
      let time = this.parseTime(timeFirst[1]);
      if (time === null) return null;
      return this.inlineMessage(timeFirst[2], timeFirst[3], time, capturedAtEpochMs);
    }

    let senderFirst = value.match(/^([^\s]{1,20})\s+((?:昨天\s*)?(?:[01]?\d|2[0-3]):[0-5]\d)\s+(.+)$/);
    if (senderFirst !== null) {
      let time = this.parseTime(senderFirst[2]);
      if (time === null) return null;
      return this.inlineMessage(senderFirst[1], senderFirst[3], time, capturedAtEpochMs);
    }
    return null;
  }

  private inlineMessage(sender: string, text: string, time: DetectedTime,
    capturedAtEpochMs: number): ParsedChatMessage {
    let normalizedText = this.normalizeText(text);
    let imageHash = this.imageHash(normalizedText);
    return {
      sender: this.normalizeText(sender),
      timeText: time.text,
      detectedMinuteOfDay: time.minuteOfDay,
      approxTimestampEpochMs: this.approxEpoch(capturedAtEpochMs, time.minuteOfDay, time.dayOffset),
      text: normalizedText,
      imageHash: imageHash,
      contentKind: imageHash.length > 0 || this.isImagePlaceholder(normalizedText) ?
        ChatMessageContentKind.IMAGE : ChatMessageContentKind.TEXT,
      relativePosition: 0,
      sourceFrameEvidenceIds: [],
      frameOrderNo: 0,
      localOrderNo: 0
    };
  }

  private parseTime(value: string): DetectedTime | null {
    let normalized = this.normalizeText(value);
    let match = normalized.match(/^(昨天\s*)?([01]?\d|2[0-3]):([0-5]\d)$/);
    if (match === null) return null;
    let hour = Number(match[2]);
    let minute = Number(match[3]);
    return {
      text: `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`,
      minuteOfDay: hour * 60 + minute,
      dayOffset: match[1] === undefined ? 0 : -1
    };
  }

  private isStandaloneTime(value: string): boolean {
    return /^(昨天\s*)?(?:[01]?\d|2[0-3]):[0-5]\d$/.test(this.normalizeText(value));
  }

  private looksLikeSender(lines: CaptureOcrLineEvidence[], index: number): boolean {
    let line = lines[index];
    if (index + 1 >= lines.length) return false;
    let value = this.senderFromLine(line.value);
    if (value.length === 0 || value.length > 16) return false;
    if (/[:：，。！？!?]/.test(value)) return false;
    let next = lines[index + 1];
    if (this.parseTime(next.value) !== null) return false;
    let verticalGap = next.top - line.bottom;
    if (verticalGap < -8 || verticalGap > 90) return false;
    return Math.abs(next.left - line.left) <= 180;
  }

  private senderFromLine(value: string): string {
    let normalized = this.normalizeText(value);
    if (normalized.endsWith(':') || normalized.endsWith('：')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  private imageHash(value: string): string {
    let match = this.normalizeText(value).match(/^\[图片:([A-Za-z0-9_-]{2,80})\]$/);
    return match === null ? '' : match[1];
  }

  private isImagePlaceholder(value: string): boolean {
    let normalized = this.normalizeText(value);
    return normalized === '图片' || normalized === '[图片]' || normalized.startsWith('[图片:');
  }

  private approxEpoch(capturedAtEpochMs: number, minuteOfDay: number, dayOffset: number): number {
    let date = new Date(capturedAtEpochMs);
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() + dayOffset);
    return date.getTime() + minuteOfDay * 60 * 1000;
  }

  private relativePosition(line: CaptureOcrLineEvidence, height: number): number {
    if (height <= 0) return line.top;
    let center = (line.top + line.bottom) / 2;
    return Math.round(center * 1000 / height);
  }

  private normalizeText(value: string): string {
    return value.trim().replace(/\s+/g, ' ');
  }
}
