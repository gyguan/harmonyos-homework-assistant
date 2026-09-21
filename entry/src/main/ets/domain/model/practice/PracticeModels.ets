export enum PracticeGrade {
  G1 = 'G1',
  G2 = 'G2',
  G3 = 'G3',
  G4 = 'G4',
  G5 = 'G5',
  G6 = 'G6'
}

export enum PracticeSubject {
  CHINESE = 'CHINESE',
  MATH = 'MATH',
  ENGLISH = 'ENGLISH',
  THINKING = 'THINKING'
}

export enum PracticeSemester {
  ALL = 'ALL',
  S1 = 'S1',
  S2 = 'S2'
}

export enum PracticeTrack {
  TEXTBOOK_SYNC = 'TEXTBOOK_SYNC',
  EXTRACURRICULAR = 'EXTRACURRICULAR'
}

export enum PracticeTrackFilter {
  ALL = 'ALL',
  TEXTBOOK_SYNC = 'TEXTBOOK_SYNC',
  EXTRACURRICULAR = 'EXTRACURRICULAR'
}

export enum PracticePassFilter {
  ALL = 'ALL',
  PASSED = 'PASSED',
  NOT_PASSED = 'NOT_PASSED'
}

export enum PracticeDifficulty {
  L1 = 'L1',
  L2 = 'L2',
  L3 = 'L3'
}

export enum PracticeSourceType {
  PRESET = 'PRESET',
  AI_GENERATED = 'AI_GENERATED',
  PARENT_CREATED = 'PARENT_CREATED',
  IMPORTED = 'IMPORTED'
}

export enum PracticePaperStatus {
  PUBLISHED = 'PUBLISHED',
  ARCHIVED = 'ARCHIVED'
}

export enum PracticeQuestionType {
  SINGLE_CHOICE = 'SINGLE_CHOICE',
  MULTIPLE_CHOICE = 'MULTIPLE_CHOICE',
  FILL_BLANK = 'FILL_BLANK',
  NUMBER = 'NUMBER',
  SHORT_TEXT = 'SHORT_TEXT'
}

export interface PracticePaper {
  id: string;
  version: number;
  grade: PracticeGrade;
  subject: PracticeSubject;
  semester: PracticeSemester;
  track: PracticeTrack;
  title: string;
  description: string;
  difficulty: PracticeDifficulty;
  questionCount: number;
  estimatedMinutes: number;
  tags: string[];
  sourceType: PracticeSourceType;
  status: PracticePaperStatus;
}

export interface PracticeQuestionOption {
  key: string;
  label: string;
}

export interface PracticeQuestion {
  id: string;
  paperId: string;
  paperVersion: number;
  orderNo: number;
  type: PracticeQuestionType;
  stem: string;
  options: PracticeQuestionOption[];
  answerSpec: string;
  explanation: string;
  hints: string[];
  tags: string[];
}

export enum PracticeAttemptMode {
  FULL = 'FULL',
  WRONG_ONLY = 'WRONG_ONLY'
}

export enum PracticeAttemptStatus {
  IN_PROGRESS = 'IN_PROGRESS',
  SUBMITTED = 'SUBMITTED'
}

export interface PracticeAnswer {
  questionId: string;
  answerValue: string;
  answeredAtEpochMs: number;
}

export interface PracticePreviousAnswer {
  questionId: string;
  answerValue: string;
  correct: boolean;
}

export interface PracticeNote {
  questionId: string;
  content: string;
  createdAtEpochMs: number;
  updatedAtEpochMs: number;
}

export interface PracticePreviousNote {
  questionId: string;
  content: string;
}

export interface PracticeAttemptSummary {
  id: string;
  paperId: string;
  paperVersion: number;
  paperTitle: string;
  grade: PracticeGrade;
  subject: PracticeSubject;
  attemptNo: number;
  mode: PracticeAttemptMode;
  status: PracticeAttemptStatus;
  sourceAttemptId: string;
  startedAtEpochMs: number;
  submittedAtEpochMs: number;
  elapsedSeconds: number;
  answeredCount: number;
  questionCount: number;
  noteCount: number;
  score: number;
  maxScore: number;
  correctCount: number;
  wrongCount: number;
}

export interface PracticeAttempt {
  id: string;
  studentId: string;
  paperId: string;
  paperVersion: number;
  attemptNo: number;
  mode: PracticeAttemptMode;
  status: PracticeAttemptStatus;
  sourceAttemptId: string;
  startedAtEpochMs: number;
  submittedAtEpochMs: number;
  elapsedSeconds: number;
  answeredCount: number;
  questionCount: number;
  noteCount: number;
  questions: PracticeQuestion[];
  answers: PracticeAnswer[];
  notes: PracticeNote[];
  previousAnswers: PracticePreviousAnswer[];
  previousNotes: PracticePreviousNote[];
}

export interface PracticeQuestionResult {
  questionId: string;
  orderNo: number;
  stem: string;
  answerValue: string;
  correctAnswer: string;
  correct: boolean;
  score: number;
  explanation: string;
  noteContent: string;
}

export interface PracticeResult {
  attemptId: string;
  paperId: string;
  paperVersion: number;
  attemptNo: number;
  mode: PracticeAttemptMode;
  score: number;
  maxScore: number;
  correctCount: number;
  wrongCount: number;
  noteCount: number;
  elapsedSeconds: number;
  questions: PracticeQuestionResult[];
}

export class PracticeTaxonomy {
  static grades(): PracticeGrade[] {
    return [
      PracticeGrade.G1,
      PracticeGrade.G2,
      PracticeGrade.G3,
      PracticeGrade.G4,
      PracticeGrade.G5,
      PracticeGrade.G6
    ];
  }

  static subjects(): PracticeSubject[] {
    return [PracticeSubject.CHINESE, PracticeSubject.MATH, PracticeSubject.ENGLISH];
  }

  static gradeLabel(grade: PracticeGrade): string {
    if (grade === PracticeGrade.G1) return '一年级';
    if (grade === PracticeGrade.G2) return '二年级';
    if (grade === PracticeGrade.G3) return '三年级';
    if (grade === PracticeGrade.G4) return '四年级';
    if (grade === PracticeGrade.G5) return '五年级';
    return '六年级';
  }

  static subjectLabel(subject: PracticeSubject): string {
    if (subject === PracticeSubject.CHINESE) return '语文';
    if (subject === PracticeSubject.MATH) return '数学';
    if (subject === PracticeSubject.ENGLISH) return '英语';
    return '思维拓展';
  }

  static semesterLabel(semester: PracticeSemester): string {
    if (semester === PracticeSemester.S1) return '上学期';
    if (semester === PracticeSemester.S2) return '下学期';
    return '全年基础';
  }

  static semesterFromStudentProfile(label: string): PracticeSemester {
    if (label.indexOf('上学期') >= 0 || label.indexOf('第一学期') >= 0 ||
      label.indexOf('秋') >= 0 || label.toUpperCase() === 'S1') return PracticeSemester.S1;
    if (label.indexOf('下学期') >= 0 || label.indexOf('第二学期') >= 0 ||
      label.indexOf('春') >= 0 || label.toUpperCase() === 'S2') return PracticeSemester.S2;
    return PracticeSemester.ALL;
  }

  static trackLabel(track: PracticeTrack): string {
    if (track === PracticeTrack.TEXTBOOK_SYNC) return '教材同步';
    return '课外拓展';
  }

  static trackFilterLabel(track: PracticeTrackFilter): string {
    if (track === PracticeTrackFilter.TEXTBOOK_SYNC) return '教材同步';
    if (track === PracticeTrackFilter.EXTRACURRICULAR) return '课外拓展';
    return '全部';
  }

  static passFilterLabel(filter: PracticePassFilter): string {
    if (filter === PracticePassFilter.PASSED) return '已通过';
    if (filter === PracticePassFilter.NOT_PASSED) return '未通过';
    return '全部';
  }

  static difficultyLabel(difficulty: PracticeDifficulty): string {
    if (difficulty === PracticeDifficulty.L1) return '基础';
    if (difficulty === PracticeDifficulty.L2) return '提升';
    return '挑战';
  }

  static gradeFromStudentProfile(label: string): PracticeGrade {
    if (label.indexOf('一年级') >= 0 || label.indexOf('一（') >= 0) return PracticeGrade.G1;
    if (label.indexOf('二年级') >= 0 || label.indexOf('二（') >= 0) return PracticeGrade.G2;
    if (label.indexOf('三年级') >= 0 || label.indexOf('三（') >= 0) return PracticeGrade.G3;
    if (label.indexOf('四年级') >= 0 || label.indexOf('四（') >= 0) return PracticeGrade.G4;
    if (label.indexOf('五年级') >= 0 || label.indexOf('五（') >= 0) return PracticeGrade.G5;
    if (label.indexOf('六年级') >= 0 || label.indexOf('六（') >= 0) return PracticeGrade.G6;
    return PracticeGrade.G2;
  }
}
