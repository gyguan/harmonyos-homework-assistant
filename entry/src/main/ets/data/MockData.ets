import {
  AppSettings,
  Assignment,
  AssignmentStatus,
  AssignmentType,
  CandidateAssignment,
  DashboardSummary,
  HomeworkImportSourceKind,
  RawHomeworkImport,
  StudentProfile,
  Subject,
  TodaySummary
} from '../domain/model/HomeworkModels';

export class MockData {
  static readonly students: StudentProfile[] = [
    {
      id: 'student-xiaoyu-001',
      name: '小宇',
      grade: '三年级',
      className: '三（2）班',
      semester: '上学期',
      textbookSummary: '语文部编版 · 数学北师大版 · 英语沪教版'
    },
    {
      id: 'student-xiaomi-002',
      name: '小米',
      grade: '一年级',
      className: '一（5）班',
      semester: '上学期',
      textbookSummary: '语文部编版 · 数学北师大版 · 英语沪教版'
    }
  ];

  static readonly settings: AppSettings = {
    students: MockData.students,
    activeStudentId: 'student-xiaoyu-001',
    tutorGuidanceFirst: true,
    directAnswerAllowed: false
  };

  static readonly assignments: Assignment[] = [
    {
      id: 'a-math-001',
      studentId: 'student-xiaoyu-001',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'MATH',
      subject: Subject.MATH,
      title: '练习册 P26 第 1～6 题',
      instruction: '先独立完成，再用红笔订正。完成后拍照上传。',
      textbookRef: '北师大版三年级上册 · 第三单元 加与减',
      dueAtEpochMs: Date.now() + 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '20:30 前',
      status: AssignmentStatus.IN_PROGRESS,
      expectedMinutes: 25,
      startedAtEpochMs: Date.now() - 5 * 60 * 1000,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: ['讲解视频 03:24', '练习说明 PDF']
    },
    {
      id: 'a-chinese-001',
      studentId: 'student-xiaoyu-001',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'CHINESE',
      subject: Subject.CHINESE,
      title: '朗读《秋天的雨》第 2～4 自然段',
      instruction: '有感情朗读两遍并提交录音。',
      textbookRef: '部编版三年级上册 · 第二单元',
      dueAtEpochMs: Date.now() - 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '已完成',
      status: AssignmentStatus.COMPLETED,
      expectedMinutes: 15,
      startedAtEpochMs: Date.now() - 18 * 60 * 1000,
      finishedAtEpochMs: Date.now() - 4 * 60 * 1000,
      elapsedSeconds: 14 * 60,
      reviewNote: '朗读很认真，明天继续保持。',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: ['老师示范音频']
    },
    {
      id: 'a-english-001',
      studentId: 'student-xiaoyu-001',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'ENGLISH',
      subject: Subject.ENGLISH,
      title: '听读 Unit 3 Look and learn',
      instruction: '跟读两遍，注意单词发音。',
      textbookRef: '沪教版三年级上册 · Unit 3',
      dueAtEpochMs: Date.now() + 2 * 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '21:00 前',
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: 15,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: ['课文音频']
    },
    {
      id: 'a-overdue-001',
      studentId: 'student-xiaoyu-001',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'MATH',
      subject: Subject.MATH,
      title: '错题订正 3 题',
      instruction: '订正并写出错误原因。',
      textbookRef: '北师大版三年级上册',
      dueAtEpochMs: Date.now() - 24 * 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '昨天 21:00',
      status: AssignmentStatus.OVERDUE,
      expectedMinutes: 20,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    },
    {
      id: 'a-xiaomi-chinese-001',
      studentId: 'student-xiaomi-002',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'CHINESE',
      subject: Subject.CHINESE,
      title: '拼音 a o e 各读三遍',
      instruction: '指读并录音一次。',
      textbookRef: '部编版一年级上册 · 拼音单元',
      dueAtEpochMs: Date.now() + 2 * 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '今晚',
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: 10,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    },
    {
      id: 'a-xiaomi-math-001',
      studentId: 'student-xiaomi-002',
      candidateId: '',
      assignmentType: AssignmentType.SCHOOL,
      subjectCode: 'MATH',
      subject: Subject.MATH,
      title: '口算 10 题',
      instruction: '独立完成 10 以内加减法。',
      textbookRef: '北师大版一年级上册',
      dueAtEpochMs: Date.now() + 3 * 60 * 60 * 1000,
      dueTimezone: 'Asia/Shanghai',
      dueText: '今晚',
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: 10,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    }
  ];

  static readonly todaySummary: TodaySummary = {
    completed: 1,
    total: 3,
    attention: 1,
    undated: 0,
    nextAssignmentId: 'a-math-001'
  };

  static readonly dashboard: DashboardSummary = {
    completed: 1,
    inProgress: 1,
    paused: 0,
    notStarted: 1,
    overdue: 1,
    readyToSubmit: 0,
    submitted: 0,
    needsRework: 0
  };

  static readonly rawImports: RawHomeworkImport[] = [
    {
      id: 'import-001',
      studentId: 'student-xiaoyu-001',
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: '三（2）班微信群截图 · 19:01',
      resourceUri: 'mock://wechat-homework-screenshot-001',
      rawText: '今天作业：语文背诵第12课古诗两首；数学练习册32页；英语听读U4，明天检查。'
    },
    {
      id: 'import-002',
      studentId: 'student-xiaomi-002',
      sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: '一（5）班老师文字 · 18:40',
      resourceUri: '',
      rawText: '语文：拼音a o e各读三遍；数学：口算10题。'
    }
  ];

  static readonly candidates: CandidateAssignment[] = [
    {
      id: 'c-1',
      studentId: 'student-xiaoyu-001',
      subject: Subject.CHINESE,
      title: '背诵第 12 课《古诗两首》',
      instruction: '按老师要求完成背诵，明天检查。',
      textbookRef: '部编版三年级上册 · 第 12 课',
      dueText: '明天',
      expectedMinutes: 15,
      sourceEvidence: {
        sourceLabel: '三（2）班微信群截图 · 19:01',
        excerpt: '语文背诵第12课古诗两首'
      },
      confidence: 0.96
    },
    {
      id: 'c-2',
      studentId: 'student-xiaoyu-001',
      subject: Subject.MATH,
      title: '完成练习册 P32',
      instruction: '完成练习册第 32 页，明天检查。',
      textbookRef: '北师大版三年级上册 · 待家长确认页码',
      dueText: '明天',
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: '三（2）班微信群截图 · 19:01',
        excerpt: '数学练习册32页'
      },
      confidence: 0.72
    },
    {
      id: 'c-3',
      studentId: 'student-xiaoyu-001',
      subject: Subject.ENGLISH,
      title: '听读 Unit 4',
      instruction: '完成 Unit 4 听读，明天检查。',
      textbookRef: '沪教版三年级上册 · Unit 4',
      dueText: '明天',
      expectedMinutes: 15,
      sourceEvidence: {
        sourceLabel: '三（2）班微信群截图 · 19:01',
        excerpt: '英语听读U4'
      },
      confidence: 0.95
    }
  ];

  static readonly offlineCacheNote: string = '已缓存当前孩子的今日作业与老师资料。';
  static readonly tutorUnavailableNote: string = 'AI Tutor 暂时不可用，但作业查看与提交能力不受影响。';
}
