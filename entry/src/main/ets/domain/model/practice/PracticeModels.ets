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

export interface PracticeAttempt {
  id: string;
  studentId: string;
  paperId: string;
  paperVersion: number;
  attemptNo: number;
  mode: PracticeAttemptMode;
  status: PracticeAttemptStatus;
  startedAtEpochMs: number;
  submittedAtEpochMs: number;
  elapsedSeconds: number;
  answeredCount: number;
  questionCount: number;
  questions: PracticeQuestion[];
  answers: PracticeAnswer[];
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
}

export interface PracticeResult {
  attemptId: string;
  paperId: string;
  paperVersion: number;
  attemptNo: number;
  score: number;
  maxScore: number;
  correctCount: number;
  wrongCount: number;
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
    return PracticeGrade.G3;
  }
}
