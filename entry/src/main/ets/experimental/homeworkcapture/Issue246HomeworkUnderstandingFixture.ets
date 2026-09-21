import { HomeworkUnderstandingPipeline } from '../../application/understanding/HomeworkUnderstandingPipeline';
import {
  HomeworkMessageClassification,
  HomeworkUnderstandingConfig,
  HomeworkUnderstandingResult,
  TeacherDirectoryEntry
} from '../../domain/model/HomeworkUnderstandingModels';
import { HomeworkImportSourceType, ImportedMessage } from '../../domain/model/ImportModels';
import { Subject } from '../../domain/model/HomeworkModels';

interface FixtureMessage {
  sender: string;
  text: string;
}

interface Issue246FixtureCase {
  id: string;
  messages: FixtureMessage[];
  expectedClassifications: HomeworkMessageClassification[];
  expectedTitles: string[];
  expectedSubjects: Subject[];
  expectedPendingReview: number;
  groupingCase: boolean;
  revisionCase: boolean;
}

export interface Issue246QualityMetrics {
  fixtureVersion: string;
  caseCount: number;
  classificationAccuracy: number;
  classificationCorrect: number;
  classificationTotal: number;
  groupingPassed: number;
  groupingTotal: number;
  revisionPassed: number;
  revisionTotal: number;
  taskExtractionPassed: number;
  taskExtractionTotal: number;
  evidencePassed: number;
  evidenceTotal: number;
  passed: boolean;
}

export class Issue246HomeworkUnderstandingFixture {
  static readonly VERSION: string = '1.0';

  static run(): Issue246QualityMetrics {
    let pipeline = new HomeworkUnderstandingPipeline();
    let cases = this.cases();
    let classificationCorrect = 0;
    let classificationTotal = 0;
    let groupingPassed = 0;
    let groupingTotal = 0;
    let revisionPassed = 0;
    let revisionTotal = 0;
    let taskExtractionPassed = 0;
    let evidencePassed = 0;
    let evidenceTotal = 0;

    for (let fixtureCase of cases) {
      let messages = this.messages(fixtureCase.id, fixtureCase.messages);
      let result = pipeline.understand(
        `issue246-${fixtureCase.id}`,
        'student-fixture',
        `#246 Fixture ${fixtureCase.id}`,
        `${HomeworkImportSourceType.SCREEN_CAPTURE}`,
        messages,
        this.config());

      for (let i = 0; i < fixtureCase.expectedClassifications.length; i++) {
        classificationTotal++;
        if (i < result.classifiedMessages.length &&
          result.classifiedMessages[i].classification === fixtureCase.expectedClassifications[i]) {
          classificationCorrect++;
        }
      }

      let extractionPass = this.matchesCandidates(
        result, fixtureCase.expectedTitles, fixtureCase.expectedSubjects) &&
        result.pendingReviewMessageIds.length === fixtureCase.expectedPendingReview;
      if (extractionPass) taskExtractionPassed++;

      if (fixtureCase.groupingCase) {
        groupingTotal++;
        if (extractionPass) groupingPassed++;
      }
      if (fixtureCase.revisionCase) {
        revisionTotal++;
        if (extractionPass) revisionPassed++;
      }

      for (let candidate of result.candidates) {
        evidenceTotal++;
        if (candidate.sourceEvidence.sourceMessageIds !== undefined &&
          candidate.sourceEvidence.sourceMessageIds!.length > 0 &&
          candidate.sourceEvidence.batchId === `issue246-${fixtureCase.id}`) {
          evidencePassed++;
        }
      }

      if (fixtureCase.id === 'C06-CORRECTION-32-33' && result.candidates.length === 1) {
        evidenceTotal++;
        let ids = result.candidates[0].sourceEvidence.sourceMessageIds;
        if (ids !== undefined && ids.length === 2) evidencePassed++;
      }
    }

    let accuracy = classificationTotal === 0 ? 0 : classificationCorrect / classificationTotal;
    let passed = cases.length >= 20 &&
      accuracy === 1 &&
      groupingPassed === groupingTotal &&
      revisionPassed === revisionTotal &&
      taskExtractionPassed === cases.length &&
      evidencePassed === evidenceTotal;

    return {
      fixtureVersion: this.VERSION,
      caseCount: cases.length,
      classificationAccuracy: accuracy,
      classificationCorrect: classificationCorrect,
      classificationTotal: classificationTotal,
      groupingPassed: groupingPassed,
      groupingTotal: groupingTotal,
      revisionPassed: revisionPassed,
      revisionTotal: revisionTotal,
      taskExtractionPassed: taskExtractionPassed,
      taskExtractionTotal: cases.length,
      evidencePassed: evidencePassed,
      evidenceTotal: evidenceTotal,
      passed: passed
    };
  }

  private static config(): HomeworkUnderstandingConfig {
    let directory: TeacherDirectoryEntry[] = [
      {
        teacherId: 'teacher-wang',
        displayName: '王老师',
        aliases: ['王老师（语文）', '王老师语文', '王老师'],
        subject: Subject.CHINESE
      },
      {
        teacherId: 'teacher-li',
        displayName: '李老师',
        aliases: ['李老师（数学）', '李老师数学', '李老师'],
        subject: Subject.MATH
      },
      {
        teacherId: 'teacher-amy',
        displayName: 'Amy老师',
        aliases: ['Amy', 'Amy老师', '英语Amy'],
        subject: Subject.ENGLISH
      }
    ];
    return { teacherDirectory: directory };
  }

  private static cases(): Issue246FixtureCase[] {
    return [
      {
        id: 'C01-SINGLE-CHINESE',
        messages: [{ sender: '王老师', text: '今晚语文：\n1. 生字词写两遍\n2. 朗读第8课三遍' }],
        expectedClassifications: [HomeworkMessageClassification.HOMEWORK],
        expectedTitles: ['生字词写两遍', '朗读第8课三遍'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C02-SINGLE-MATH',
        messages: [{ sender: '李老师', text: '数学作业：\n1. 口算20题\n2. 完成练习册15页' }],
        expectedClassifications: [HomeworkMessageClassification.HOMEWORK],
        expectedTitles: ['口算20题', '完成练习册15页'],
        expectedSubjects: [Subject.MATH, Subject.MATH],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C03-ENGLISH-ALIAS',
        messages: [{ sender: 'Amy', text: '英语作业：朗读U2课文' }],
        expectedClassifications: [HomeworkMessageClassification.HOMEWORK],
        expectedTitles: ['朗读U2课文'],
        expectedSubjects: [Subject.ENGLISH],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C04-PARENT-ACK',
        messages: [{ sender: '家长甲', text: '收到' }],
        expectedClassifications: [HomeworkMessageClassification.CHAT],
        expectedTitles: [], expectedSubjects: [],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C05-SUPPLEMENT',
        messages: [
          { sender: '王老师', text: '语文作业：练习册32页' },
          { sender: '王老师', text: '补充一下：默写第8课生字' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK_REVISION
        ],
        expectedTitles: ['练习册32页', '默写第8课生字'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: true
      },
      {
        id: 'C06-CORRECTION-32-33',
        messages: [
          { sender: '王老师', text: '语文作业：练习册32页' },
          { sender: '王老师', text: '刚才说错了，练习册是33页' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK_REVISION
        ],
        expectedTitles: ['练习册33页'],
        expectedSubjects: [Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: true
      },
      {
        id: 'C07-CANCEL-THIRD',
        messages: [
          { sender: '王老师', text: '语文作业：\n1. 生字写两遍\n2. 朗读第8课\n3. 练习册20页' },
          { sender: '王老师', text: '第三题不用做' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK_REVISION
        ],
        expectedTitles: ['生字写两遍', '朗读第8课'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: true
      },
      {
        id: 'C08-PREPARATION',
        messages: [{ sender: '王老师', text: '另外明天带一本课外书' }],
        expectedClassifications: [HomeworkMessageClassification.PREPARATION],
        expectedTitles: ['明日准备：带一本课外书'],
        expectedSubjects: [Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C09-NOTICE',
        messages: [{ sender: '王老师', text: '明天下午三点家长会，请准时参加' }],
        expectedClassifications: [HomeworkMessageClassification.NOTICE],
        expectedTitles: [], expectedSubjects: [],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C10-CONSECUTIVE',
        messages: [
          { sender: '王老师', text: '语文作业：生字写两遍' },
          { sender: '王老师', text: '朗读第8课三遍' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK
        ],
        expectedTitles: ['生字写两遍', '朗读第8课三遍'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: false
      },
      {
        id: 'C11-UNKNOWN-SENDER',
        messages: [{ sender: '群友甲', text: '今晚作业：练习册20页' }],
        expectedClassifications: [HomeworkMessageClassification.UNKNOWN],
        expectedTitles: [], expectedSubjects: [],
        expectedPendingReview: 1, groupingCase: false, revisionCase: false
      },
      {
        id: 'C12-TEACHER-ALIAS',
        messages: [{ sender: '王老师（语文）', text: '语文作业：预习第9课' }],
        expectedClassifications: [HomeworkMessageClassification.HOMEWORK],
        expectedTitles: ['预习第9课'],
        expectedSubjects: [Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C13-EXACT-TEACHER',
        messages: [{ sender: '李老师', text: '数学作业：口算30题' }],
        expectedClassifications: [HomeworkMessageClassification.HOMEWORK],
        expectedTitles: ['口算30题'],
        expectedSubjects: [Subject.MATH],
        expectedPendingReview: 0, groupingCase: false, revisionCase: false
      },
      {
        id: 'C14-MULTI-SUBJECT',
        messages: [
          { sender: '王老师', text: '语文作业：朗读第8课' },
          { sender: '李老师', text: '数学作业：口算20题' },
          { sender: 'Amy老师', text: '英语作业：听读U2三遍' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK
        ],
        expectedTitles: ['朗读第8课', '口算20题', '听读U2三遍'],
        expectedSubjects: [Subject.CHINESE, Subject.MATH, Subject.ENGLISH],
        expectedPendingReview: 0, groupingCase: true, revisionCase: false
      },
      {
        id: 'C15-GENERIC-REPLACE',
        messages: [
          { sender: '王老师', text: '语文作业：朗读第8课' },
          { sender: '王老师', text: '改成朗读第9课三遍' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK_REVISION
        ],
        expectedTitles: ['朗读第9课三遍'],
        expectedSubjects: [Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: true
      },
      {
        id: 'C16-AUTHORITATIVE',
        messages: [
          { sender: '王老师', text: '语文作业：\n1. 生字写两遍\n2. 朗读第8课' },
          { sender: '王老师', text: '以这条为准：\n1. 生字写三遍\n2. 朗读第9课' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.HOMEWORK_REVISION
        ],
        expectedTitles: ['生字写三遍', '朗读第9课'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: true
      },
      {
        id: 'C17-HOMEWORK-PREP',
        messages: [
          { sender: '王老师', text: '语文作业：默写第8课生字' },
          { sender: '王老师', text: '明天带一本课外书' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.PREPARATION
        ],
        expectedTitles: ['默写第8课生字', '明日准备：带一本课外书'],
        expectedSubjects: [Subject.CHINESE, Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: false
      },
      {
        id: 'C18-NOTICE-PLUS-HOMEWORK',
        messages: [
          { sender: '李老师', text: '明天下午四点家长会' },
          { sender: '李老师', text: '数学作业：完成练习册18页' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.NOTICE,
          HomeworkMessageClassification.HOMEWORK
        ],
        expectedTitles: ['完成练习册18页'],
        expectedSubjects: [Subject.MATH],
        expectedPendingReview: 0, groupingCase: true, revisionCase: false
      },
      {
        id: 'C19-PARENT-THANKS',
        messages: [
          { sender: '王老师', text: '语文作业：朗读第8课' },
          { sender: '家长乙', text: '谢谢老师' }
        ],
        expectedClassifications: [
          HomeworkMessageClassification.HOMEWORK,
          HomeworkMessageClassification.CHAT
        ],
        expectedTitles: ['朗读第8课'],
        expectedSubjects: [Subject.CHINESE],
        expectedPendingReview: 0, groupingCase: true, revisionCase: false
      },
      {
        id: 'C20-TEACHER-UNKNOWN',
        messages: [{ sender: '王老师', text: '明天注意一下课堂安排' }],
        expectedClassifications: [HomeworkMessageClassification.UNKNOWN],
        expectedTitles: [], expectedSubjects: [],
        expectedPendingReview: 1, groupingCase: false, revisionCase: false
      }
    ];
  }

  private static messages(caseId: string, values: FixtureMessage[]): ImportedMessage[] {
    let result: ImportedMessage[] = [];
    for (let i = 0; i < values.length; i++) {
      let id = `${caseId}-m${i + 1}`;
      result.push({
        id: id,
        batchId: `issue246-${caseId}`,
        sender: values[i].sender,
        timestampEpochMs: 1790000000000 + i * 60000,
        text: values[i].text,
        attachments: [],
        sourceEvidence: {
          sourceType: HomeworkImportSourceType.SCREEN_CAPTURE,
          sourceMessageIds: [id],
          sourceFrameEvidenceIds: [`${caseId}-frame-${i + 1}`],
          rawText: values[i].text,
          imageRef: '',
          capturedAtEpochMs: 1790000000000 + i * 60000
        },
        fingerprint: `${caseId}-fingerprint-${i + 1}`,
        orderNo: i + 1
      });
    }
    return result;
  }

  private static matchesCandidates(result: HomeworkUnderstandingResult,
    expectedTitles: string[], expectedSubjects: Subject[]): boolean {
    if (result.candidates.length !== expectedTitles.length ||
      expectedTitles.length !== expectedSubjects.length) return false;
    for (let i = 0; i < expectedTitles.length; i++) {
      if (result.candidates[i].title !== expectedTitles[i]) return false;
      if (result.candidates[i].subject !== expectedSubjects[i]) return false;
    }
    return true;
  }
}
