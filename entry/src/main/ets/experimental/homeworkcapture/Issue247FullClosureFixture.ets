import { HomeworkCaptureWorkflowService } from '../../application/capture/HomeworkCaptureWorkflowService';
import { HomeworkSourceProfileService } from '../../application/capture/HomeworkSourceProfileService';
import { DeterministicChatReconstructor } from '../../application/capture/DeterministicChatReconstructor';
import { HomeworkUnderstandingPipeline } from '../../application/understanding/HomeworkUnderstandingPipeline';
import {
  CaptureFrameEvidence,
  CaptureOcrLineEvidence
} from '../../domain/model/CaptureModels';
import {
  HomeworkSourceProfile,
  HomeworkSourceTeacherAlias,
  SourceGroupValidationStatus
} from '../../domain/model/HomeworkSourceProfileModels';
import { HomeworkImportSourceType, ImportedMessage } from '../../domain/model/ImportModels';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';

export interface Issue247ClosureResult {
  groupMatched: boolean;
  mismatchDetected: boolean;
  unrecognizedRequiresConfirmation: boolean;
  timeBoundaryReached: boolean;
  earliestDetectedTime: string;
  uniqueMessageCount: number;
  inWindowMessageCount: number;
  outOfRangeFiltered: boolean;
  parentChatFilteredFromCandidates: boolean;
  correctionResolved: boolean;
  homeworkTasksGenerated: boolean;
  preparationGenerated: boolean;
  candidateEvidenceTracePassed: boolean;
  assignmentCandidateTraceContractPresent: boolean;
  passed: boolean;
}

export class Issue247FullClosureFixture {
  private static readonly BASE_EPOCH: number = 1790000000000;

  static run(): Issue247ClosureResult {
    let profile = this.profile();
    let reconstructor = new DeterministicChatReconstructor();
    let reconstruction = reconstructor.reconstruct(
      'issue247-batch',
      this.frames(),
      { targetStartMinuteOfDay: profile.defaultStartMinuteOfDay });

    let workflow = HomeworkCaptureWorkflowService.instance;
    let groupMatched = workflow.validateGroupTitle(
      profile.groupTitle, reconstruction.groupTitle) === SourceGroupValidationStatus.MATCHED;
    let mismatchDetected = workflow.validateGroupTitle(
      profile.groupTitle, '其他班家长群') === SourceGroupValidationStatus.MISMATCH;
    let unrecognizedRequiresConfirmation = workflow.validateGroupTitle(
      profile.groupTitle, '') === SourceGroupValidationStatus.UNRECOGNIZED;

    let startEpoch = this.startEpoch(profile.defaultStartMinuteOfDay);
    let inWindow: ImportedMessage[] = [];
    let outOfRangeFiltered = false;
    for (let message of reconstruction.messages) {
      if (message.timestampEpochMs > 0 && message.timestampEpochMs < startEpoch) {
        outOfRangeFiltered = true;
        continue;
      }
      inWindow.push(message);
    }

    let understanding = new HomeworkUnderstandingPipeline().understand(
      'issue247-batch',
      'student-fixture',
      '二(3)班家长群 · 今日作业',
      `${HomeworkImportSourceType.SCREEN_CAPTURE}`,
      inWindow,
      HomeworkSourceProfileService.instance.understandingConfig(profile));

    let titles: string[] = [];
    for (let candidate of understanding.candidates) titles.push(candidate.title);

    let parentChatFiltered = true;
    for (let candidate of understanding.candidates) {
      let ids = candidate.sourceEvidence.sourceMessageIds;
      if (ids !== undefined && ids.indexOf('issue247-batch-chat-4') >= 0) parentChatFiltered = false;
    }

    let correctionResolved = titles.indexOf('练习册33页') >= 0 &&
      titles.indexOf('练习册32页') < 0 &&
      this.hasCorrectionEvidence(understanding.candidates);
    let homeworkGenerated = titles.indexOf('生字写两遍') >= 0 &&
      titles.indexOf('练习册33页') >= 0;
    let preparationGenerated = titles.indexOf('明日准备：带一本课外书') >= 0;
    let evidenceTrace = this.allCandidatesHaveEvidence(understanding.candidates);

    let passed = groupMatched && mismatchDetected && unrecognizedRequiresConfirmation &&
      reconstruction.timeBoundaryReached &&
      reconstruction.earliestDetectedTime === '14:58' &&
      reconstruction.messages.length === 5 &&
      inWindow.length === 4 &&
      outOfRangeFiltered &&
      parentChatFiltered &&
      correctionResolved &&
      homeworkGenerated &&
      preparationGenerated &&
      understanding.candidates.length === 3 &&
      evidenceTrace;

    return {
      groupMatched: groupMatched,
      mismatchDetected: mismatchDetected,
      unrecognizedRequiresConfirmation: unrecognizedRequiresConfirmation,
      timeBoundaryReached: reconstruction.timeBoundaryReached,
      earliestDetectedTime: reconstruction.earliestDetectedTime,
      uniqueMessageCount: reconstruction.messages.length,
      inWindowMessageCount: inWindow.length,
      outOfRangeFiltered: outOfRangeFiltered,
      parentChatFilteredFromCandidates: parentChatFiltered,
      correctionResolved: correctionResolved,
      homeworkTasksGenerated: homeworkGenerated,
      preparationGenerated: preparationGenerated,
      candidateEvidenceTracePassed: evidenceTrace,
      assignmentCandidateTraceContractPresent: true,
      passed: passed
    };
  }

  private static profile(): HomeworkSourceProfile {
    let teacher: HomeworkSourceTeacherAlias = {
      displayName: '王老师',
      aliases: ['王老师（语文）'],
      subject: Subject.CHINESE
    };
    return {
      id: 'issue247-profile',
      name: '深圳 XX 小学 二(3)班',
      groupTitle: '二(3)班家长群',
      studentId: 'student-fixture',
      teacherAliases: [teacher],
      defaultStartMinuteOfDay: 15 * 60,
      enabled: true,
      createdAtEpochMs: this.BASE_EPOCH,
      updatedAtEpochMs: this.BASE_EPOCH,
      lastUsedAtEpochMs: 0
    };
  }

  private static frames(): CaptureFrameEvidence[] {
    return [
      this.frame(1, [
        '17:50 家长A 收到',
        '18:03 王老师 另外明天记得带一本课外书'
      ]),
      this.frame(2, [
        '17:42 王老师 练习册刚才说错了，是33页',
        '17:50 家长A 收到'
      ]),
      this.frame(3, [
        '17:31 王老师 今晚语文：生字写两遍，练习册32页',
        '17:42 王老师 练习册刚才说错了，是33页'
      ]),
      this.frame(4, [
        '14:58 家长B 请问明天几点到校？',
        '17:31 王老师 今晚语文：生字写两遍，练习册32页'
      ])
    ];
  }

  private static frame(orderNo: number, messages: string[]): CaptureFrameEvidence {
    let lines: CaptureOcrLineEvidence[] = [
      this.line('二(3)班家长群', 260, 30, 540, 70)
    ];
    for (let i = 0; i < messages.length; i++) {
      lines.push(this.line(messages[i], 80, 220 + i * 190, 720, 270 + i * 190));
    }
    let values: string[] = [];
    for (let line of lines) values.push(line.value);
    return {
      id: `issue247-frame-${orderNo}`,
      sessionId: 'issue247-session',
      sequence: orderNo,
      capturedAtEpochMs: this.BASE_EPOCH + orderNo * 1000,
      runtimeTimestamp: orderNo * 1000,
      width: 800,
      height: 1200,
      fingerprint: `issue247-fingerprint-${orderNo}`,
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

  private static startEpoch(minuteOfDay: number): number {
    let date = new Date(this.BASE_EPOCH);
    date.setHours(0, 0, 0, 0);
    return date.getTime() + minuteOfDay * 60 * 1000;
  }

  private static hasCorrectionEvidence(candidates: CandidateAssignment[]): boolean {
    for (let candidate of candidates) {
      if (candidate.title !== '练习册33页') continue;
      let ids = candidate.sourceEvidence.sourceMessageIds;
      return ids !== undefined && ids.length === 2;
    }
    return false;
  }

  private static allCandidatesHaveEvidence(candidates: CandidateAssignment[]): boolean {
    if (candidates.length === 0) return false;
    for (let candidate of candidates) {
      if (candidate.sourceEvidence.batchId !== 'issue247-batch') return false;
      let ids = candidate.sourceEvidence.sourceMessageIds;
      if (ids === undefined || ids.length === 0) return false;
    }
    return true;
  }
}
