import { DeterministicChatReconstructor } from '../../main/ets/application/capture/DeterministicChatReconstructor';
import {
  ChatReconstructionResult
} from '../../main/ets/domain/model/ChatReconstructionModels';
import {
  CaptureFrameEvidence,
  CaptureOcrLineEvidence
} from '../../main/ets/domain/model/CaptureModels';

export interface Issue245FixtureResult {
  messageCount: number;
  order: string[];
  repeatedMessageEvidenceCount: number;
  timeBoundaryReached: boolean;
  earliestDetectedTime: string;
  groupTitle: string;
  warnings: string[];
  sameTextDifferentSenderPreserved: boolean;
  sameTextDifferentTimePreserved: boolean;
  missingTimeOverlapDeduped: boolean;
  imageMessagePreserved: boolean;
  ocrFailureTolerated: boolean;
  passed: boolean;
}

export class Issue245ChatReconstructionFixture {
  private static readonly BASE_EPOCH: number = 1789952400000;

  static run(): Issue245FixtureResult {
    let reconstructor = new DeterministicChatReconstructor();
    let main = reconstructor.reconstruct(
      'issue245-main',
      [
        this.frame(1, ['17:46 家长甲 收到', '17:50 李老师 C']),
        this.frame(2, ['17:45 王老师 B', '17:46 家长甲 收到']),
        this.frame(3, ['17:42 王老师 A', '17:45 王老师 B']),
        this.frame(4, ['14:58 王老师 D', '17:42 王老师 A']),
        this.frame(5, ['17:42 王老师 A', '17:45 王老师 B'])
      ],
      { targetStartMinuteOfDay: 15 * 60 });

    let order: string[] = [];
    for (let message of main.messages) order.push(`${this.timeText(message.timestampEpochMs)} ${message.sender} ${message.text}`);

    let repeatedEvidenceCount = 0;
    for (let message of main.messages) {
      if (message.sender === '王老师' && message.text === 'A' &&
        message.sourceEvidence.sourceFrameEvidenceIds !== undefined) {
        repeatedEvidenceCount = message.sourceEvidence.sourceFrameEvidenceIds.length;
      }
    }

    let differentSender = this.sameTextDifferentSender(reconstructor);
    let differentTime = this.sameTextDifferentTime(reconstructor);
    let missingTime = this.missingTimeOverlap(reconstructor);
    let image = this.imageMessage(reconstructor);
    let failure = this.ocrFailure(reconstructor);

    let expected = [
      '14:58 王老师 D',
      '17:42 王老师 A',
      '17:45 王老师 B',
      '17:46 家长甲 收到',
      '17:50 李老师 C'
    ];
    let passed = main.messages.length === 5 &&
      this.sameOrder(order, expected) &&
      repeatedEvidenceCount === 3 &&
      main.timeBoundaryReached &&
      main.earliestDetectedTime === '14:58' &&
      main.groupTitle === '二(3)班家长群' &&
      differentSender && differentTime && missingTime && image && failure;

    return {
      messageCount: main.messages.length,
      order: order,
      repeatedMessageEvidenceCount: repeatedEvidenceCount,
      timeBoundaryReached: main.timeBoundaryReached,
      earliestDetectedTime: main.earliestDetectedTime,
      groupTitle: main.groupTitle,
      warnings: main.warnings,
      sameTextDifferentSenderPreserved: differentSender,
      sameTextDifferentTimePreserved: differentTime,
      missingTimeOverlapDeduped: missingTime,
      imageMessagePreserved: image,
      ocrFailureTolerated: failure,
      passed: passed
    };
  }

  private static sameTextDifferentSender(reconstructor: DeterministicChatReconstructor): boolean {
    let result = reconstructor.reconstruct(
      'issue245-sender',
      [
        this.frame(11, ['17:46 家长甲 收到']),
        this.frame(12, ['17:46 家长乙 收到'])
      ],
      { targetStartMinuteOfDay: -1 });
    return result.messages.length === 2 &&
      result.messages[0].sender !== result.messages[1].sender;
  }

  private static sameTextDifferentTime(reconstructor: DeterministicChatReconstructor): boolean {
    let result = reconstructor.reconstruct(
      'issue245-time',
      [
        this.frame(21, ['17:46 家长甲 收到']),
        this.frame(22, ['18:05 家长甲 收到'])
      ],
      { targetStartMinuteOfDay: -1 });
    return result.messages.length === 2 &&
      result.messages[0].timestampEpochMs !== result.messages[1].timestampEpochMs;
  }

  private static missingTimeOverlap(reconstructor: DeterministicChatReconstructor): boolean {
    let frameOne = this.customFrame(31, [
      this.line('二(3)班家长群', 260, 30, 540, 70),
      this.line('王老师：', 80, 210, 200, 245),
      this.line('请带书', 80, 252, 260, 292),
      this.line('17:50 李老师 C', 80, 410, 430, 450)
    ]);
    let frameTwo = this.customFrame(32, [
      this.line('二(3)班家长群', 260, 30, 540, 70),
      this.line('王老师：', 80, 180, 200, 215),
      this.line('请带书', 80, 222, 260, 262),
      this.line('17:50 李老师 C', 80, 380, 430, 420)
    ]);
    let result = reconstructor.reconstruct(
      'issue245-missing-time', [frameOne, frameTwo], { targetStartMinuteOfDay: -1 });
    return result.messages.length === 2 &&
      result.messages[0].sender === '王老师' &&
      result.messages[0].text === '请带书' &&
      result.messages[0].sourceEvidence.sourceFrameEvidenceIds !== undefined &&
      result.messages[0].sourceEvidence.sourceFrameEvidenceIds!.length === 2;
  }

  private static imageMessage(reconstructor: DeterministicChatReconstructor): boolean {
    let result = reconstructor.reconstruct(
      'issue245-image',
      [
        this.frame(41, ['17:40 王老师 [图片:img_001]']),
        this.frame(42, ['17:40 王老师 [图片:img_001]'])
      ],
      { targetStartMinuteOfDay: -1 });
    return result.messages.length === 1 &&
      result.messages[0].text === '[图片:img_001]' &&
      result.messages[0].fingerprint.indexOf('img_001') >= 0;
  }

  private static ocrFailure(reconstructor: DeterministicChatReconstructor): boolean {
    let failed = this.customFrame(52, []);
    failed.text = 'OCR_EXCEPTION';
    let result = reconstructor.reconstruct(
      'issue245-failure',
      [
        this.frame(51, ['17:42 王老师 A']),
        failed,
        this.frame(53, ['17:45 王老师 B'])
      ],
      { targetStartMinuteOfDay: -1 });
    return result.messages.length === 2 &&
      result.warnings.length > 0;
  }

  private static frame(orderNo: number, messages: string[]): CaptureFrameEvidence {
    let lines: CaptureOcrLineEvidence[] = [
      this.line('二(3)班家长群', 260, 30, 540, 70)
    ];
    for (let i = 0; i < messages.length; i++) {
      lines.push(this.line(messages[i], 80, 220 + i * 190, 700, 270 + i * 190));
    }
    return this.customFrame(orderNo, lines);
  }

  private static customFrame(orderNo: number, lines: CaptureOcrLineEvidence[]): CaptureFrameEvidence {
    let values: string[] = [];
    for (let line of lines) values.push(line.value);
    return {
      id: `issue245-frame-${orderNo}`,
      sessionId: 'issue245-session',
      sequence: orderNo,
      capturedAtEpochMs: this.BASE_EPOCH + orderNo * 1000,
      runtimeTimestamp: orderNo * 1000,
      width: 800,
      height: 1200,
      fingerprint: `fixture-${orderNo}`,
      text: values.join('\n'),
      lineCount: lines.length,
      lines: lines,
      orderNo: orderNo
    };
  }

  private static line(value: string, left: number, top: number,
    right: number, bottom: number): CaptureOcrLineEvidence {
    return { value: value, left: left, top: top, right: right, bottom: bottom };
  }

  private static timeText(epochMs: number): string {
    let date = new Date(epochMs);
    let hour = date.getHours();
    let minute = date.getMinutes();
    return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
  }

  private static sameOrder(actual: string[], expected: string[]): boolean {
    if (actual.length !== expected.length) return false;
    for (let i = 0; i < actual.length; i++) if (actual[i] !== expected[i]) return false;
    return true;
  }
}
