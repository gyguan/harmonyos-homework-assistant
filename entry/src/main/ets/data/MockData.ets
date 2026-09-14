import {
  Assignment,
  AssignmentStatus,
  CandidateAssignment,
  DashboardSummary,
  RawHomeworkImport,
  Subject,
  TodaySummary
} from '../domain/model/HomeworkModels';

export class MockData {
  static readonly FAMILY_ID: string = 'family-demo-001';
  static readonly STUDENT_ID: string = 'student-xiaoyu-001';

  static readonly assignments: Assignment[] = [
    {
      id: 'a-math-001',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      candidateId: '',
      subject: Subject.MATH,
      title: '练习册 P26 第 1～6 题',
      instruction: '先独立完成，再用红笔订正。完成后拍照上传。',
      textbookRef: '北师大版三年级上册 · 第三单元 加与减',
      dueText: '20:30 前',
      status: AssignmentStatus.IN_PROGRESS,
      resourceLabels: ['讲解视频 03:24', '练习说明 PDF']
    },
    {
      id: 'a-chinese-001',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      candidateId: '',
      subject: Subject.CHINESE,
      title: '朗读《秋天的雨》第 2～4 自然段',
      instruction: '有感情朗读两遍并提交录音。',
      textbookRef: '部编版三年级上册 · 第二单元',
      dueText: '已完成',
      status: AssignmentStatus.COMPLETED,
      resourceLabels: ['老师示范音频']
    },
    {
      id: 'a-english-001',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      candidateId: '',
      subject: Subject.ENGLISH,
      title: '听读 Unit 3 Look and learn',
      instruction: '跟读两遍，注意单词发音。',
      textbookRef: '沪教版三年级上册 · Unit 3',
      dueText: '21:00 前',
      status: AssignmentStatus.NOT_STARTED,
      resourceLabels: ['课文音频']
    },
    {
      id: 'a-overdue-001',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      candidateId: '',
      subject: Subject.MATH,
      title: '错题订正 3 题',
      instruction: '订正并写出错误原因。',
      textbookRef: '北师大版三年级上册',
      dueText: '昨天 21:00',
      status: AssignmentStatus.OVERDUE,
      resourceLabels: []
    }
  ];

  static readonly todaySummary: TodaySummary = {
    completed: 1,
    total: 3,
    nextAssignmentId: 'a-math-001'
  };

  static readonly dashboard: DashboardSummary = {
    completed: 1,
    inProgress: 1,
    notStarted: 1,
    overdue: 1,
    readyToSubmit: 0,
    submitted: 0,
    needsRework: 0
  };

  static readonly rawImport: RawHomeworkImport = {
    id: 'import-001',
    familyId: MockData.FAMILY_ID,
    rawText: '今天作业：语文背诵第12课古诗两首；数学练习册32页；英语听读U4，明天检查。',
    sourceLabel: '微信群聊天截图 · 19:01'
  };

  static readonly importSource: string = MockData.rawImport.rawText;

  static readonly candidates: CandidateAssignment[] = [
    {
      id: 'c-1',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      subject: Subject.CHINESE,
      title: '背诵第 12 课《古诗两首》',
      instruction: '按老师要求完成背诵，明天检查。',
      textbookRef: '部编版三年级上册 · 第 12 课',
      dueText: '明天',
      sourceEvidence: {
        sourceLabel: MockData.rawImport.sourceLabel,
        excerpt: '语文背诵第12课古诗两首'
      },
      confidence: 0.96
    },
    {
      id: 'c-2',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      subject: Subject.MATH,
      title: '完成练习册 P32',
      instruction: '完成练习册第 32 页，明天检查。',
      textbookRef: '北师大版三年级上册 · 待家长确认页码',
      dueText: '明天',
      sourceEvidence: {
        sourceLabel: MockData.rawImport.sourceLabel,
        excerpt: '数学练习册32页'
      },
      confidence: 0.72
    },
    {
      id: 'c-3',
      familyId: MockData.FAMILY_ID,
      studentId: MockData.STUDENT_ID,
      subject: Subject.ENGLISH,
      title: '听读 Unit 4',
      instruction: '完成 Unit 4 听读，明天检查。',
      textbookRef: '沪教版三年级上册 · Unit 4',
      dueText: '明天',
      sourceEvidence: {
        sourceLabel: MockData.rawImport.sourceLabel,
        excerpt: '英语听读U4'
      },
      confidence: 0.95
    }
  ];

  static readonly offlineCacheNote: string = '已缓存今日作业与老师资料，恢复网络后自动同步提交。';
  static readonly tutorUnavailableNote: string = 'AI Tutor 暂时不可用，但作业查看与提交能力不受影响。';
}
