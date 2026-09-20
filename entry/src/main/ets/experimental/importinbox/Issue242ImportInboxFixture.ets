import { HomeworkImportInboxService } from '../../application/import/HomeworkImportInboxService';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';

export class Issue242ImportInboxFixture {
  static install(studentId: string): string {
    let batchId = 'issue242-fixture-1726848000000';
    let messages: ImportedMessage[] = [
      Issue242ImportInboxFixture.message(
        batchId, 'm-1', 1, '王老师', '语文：第8课生字写两遍。'),
      Issue242ImportInboxFixture.message(
        batchId, 'm-2', 2, '家长甲', '收到，谢谢老师。'),
      Issue242ImportInboxFixture.message(
        batchId, 'm-3', 3, '王老师', '补充：朗读第8课三遍。')
    ];

    let batch: ImportBatch = {
      id: batchId,
      studentId: studentId,
      sourceType: HomeworkImportSourceType.CLIPBOARD,
      sourceLabel: '#242 本地验收 Fixture',
      sourceProfileId: '',
      createdAtEpochMs: 1726848000000,
      status: ImportBatchStatus.READY,
      messageCount: 3,
      candidateCount: 2
    };

    let candidates: CandidateAssignment[] = [
      Issue242ImportInboxFixture.candidate(
        studentId, batchId, 'fixture-c-1', Subject.CHINESE,
        '第8课生字写两遍', '语文：第8课生字写两遍。', ['m-1']),
      Issue242ImportInboxFixture.candidate(
        studentId, batchId, 'fixture-c-2', Subject.CHINESE,
        '朗读第8课三遍', '补充：朗读第8课三遍。', ['m-1', 'm-3'])
    ];

    HomeworkImportInboxService.instance.importBatch(batch, messages, candidates);
    HomeworkImportInboxService.instance.activateBatch(batchId);
    return batchId;
  }

  private static message(batchId: string, id: string, orderNo: number,
    sender: string, text: string): ImportedMessage {
    return {
      id: id,
      batchId: batchId,
      sender: sender,
      timestampEpochMs: 1726848000000 + orderNo * 60000,
      text: text,
      attachments: [],
      sourceEvidence: {
        sourceType: HomeworkImportSourceType.CLIPBOARD,
        sourceMessageIds: [id],
        rawText: text,
        imageRef: '',
        capturedAtEpochMs: 1726848000000 + orderNo * 60000
      },
      fingerprint: `${sender}:${text}`,
      orderNo: orderNo
    };
  }

  private static candidate(studentId: string, batchId: string, id: string,
    subject: Subject, title: string, excerpt: string, sourceMessageIds: string[]): CandidateAssignment {
    return {
      id: id,
      studentId: studentId,
      subject: subject,
      title: title,
      instruction: title,
      textbookRef: '待家长确认',
      dueText: '今天',
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: '#242 本地验收 Fixture',
        excerpt: excerpt,
        batchId: batchId,
        sourceType: HomeworkImportSourceType.CLIPBOARD,
        sourceMessageIds: sourceMessageIds.slice(),
        rawText: excerpt,
        imageRef: '',
        capturedAtEpochMs: 1726848000000
      },
      confidence: 1.0
    };
  }
}
