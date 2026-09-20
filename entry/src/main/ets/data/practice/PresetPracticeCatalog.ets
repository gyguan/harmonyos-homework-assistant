import {
  PracticeDifficulty,
  PracticeGrade,
  PracticePaper,
  PracticePaperStatus,
  PracticeSourceType,
  PracticeSubject,
  PracticeTaxonomy
} from '../../domain/model/practice/PracticeModels';

export class PresetPracticeCatalog {
  static papers(): PracticePaper[] {
    let result: PracticePaper[] = [];
    for (let grade of PracticeTaxonomy.grades()) {
      result.push(PresetPracticeCatalog.createPaper(grade, PracticeSubject.CHINESE));
      result.push(PresetPracticeCatalog.createPaper(grade, PracticeSubject.MATH));
      result.push(PresetPracticeCatalog.createPaper(grade, PracticeSubject.ENGLISH));
    }
    return result;
  }

  private static createPaper(grade: PracticeGrade, subject: PracticeSubject): PracticePaper {
    let subjectLabel = PracticeTaxonomy.subjectLabel(subject);
    let gradeLabel = PracticeTaxonomy.gradeLabel(grade);
    return {
      id: `${subject}-${grade}-STARTER-001`,
      version: 1,
      grade: grade,
      subject: subject,
      title: PresetPracticeCatalog.title(subject),
      description: `${gradeLabel}${subjectLabel}首批练习套卷，用于建立稳定的套卷练习入口。`,
      difficulty: PracticeDifficulty.L1,
      questionCount: 10,
      estimatedMinutes: subject === PracticeSubject.CHINESE ? 20 : 15,
      tags: PresetPracticeCatalog.tags(subject),
      sourceType: PracticeSourceType.PRESET,
      status: PracticePaperStatus.PUBLISHED
    };
  }

  private static title(subject: PracticeSubject): string {
    if (subject === PracticeSubject.CHINESE) return '语文基础训练卷';
    if (subject === PracticeSubject.MATH) return '数学基础训练卷';
    return '英语基础训练卷';
  }

  private static tags(subject: PracticeSubject): string[] {
    if (subject === PracticeSubject.CHINESE) return ['字词', '阅读'];
    if (subject === PracticeSubject.MATH) return ['计算', '应用'];
    return ['词汇', '句型'];
  }
}
