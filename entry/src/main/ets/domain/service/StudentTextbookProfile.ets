import { StudentProfile } from '../model/HomeworkModels';

export interface StudentTextbookFields {
  chineseTextbook: string;
  mathTextbook: string;
  englishTextbook: string;
  otherTextbooks: string;
}

export class StudentTextbookProfile {
  static fields(
    chineseTextbook: string,
    mathTextbook: string,
    englishTextbook: string,
    otherTextbooks: string
  ): StudentTextbookFields {
    return {
      chineseTextbook: StudentTextbookProfile.clean(chineseTextbook),
      mathTextbook: StudentTextbookProfile.clean(mathTextbook),
      englishTextbook: StudentTextbookProfile.clean(englishTextbook),
      otherTextbooks: StudentTextbookProfile.clean(otherTextbooks)
    };
  }

  static fromStudent(student: StudentProfile): StudentTextbookFields {
    let structured = StudentTextbookProfile.fields(
      student.chineseTextbook,
      student.mathTextbook,
      student.englishTextbook,
      student.otherTextbooks);
    if (!StudentTextbookProfile.empty(structured)) return structured;
    return StudentTextbookProfile.parseLegacy(student.textbookSummary);
  }

  static parseLegacy(summary: string): StudentTextbookFields {
    let result = StudentTextbookProfile.fields('', '', '', '');
    let text = StudentTextbookProfile.clean(summary);
    if (text.length === 0) return result;

    let normalized = text.split(' · ').join('；').split('|').join('；').split('｜').join('；');
    let pieces = normalized.split('；');
    let others: string[] = [];
    for (let piece of pieces) {
      let value = StudentTextbookProfile.clean(piece);
      if (value.length === 0) continue;
      if (value.indexOf('语文') === 0) result.chineseTextbook = StudentTextbookProfile.afterSubject(value, '语文');
      else if (value.indexOf('数学') === 0) result.mathTextbook = StudentTextbookProfile.afterSubject(value, '数学');
      else if (value.indexOf('英语') === 0) result.englishTextbook = StudentTextbookProfile.afterSubject(value, '英语');
      else others.push(value);
    }
    result.otherTextbooks = others.join('；');
    return result;
  }

  static summary(fields: StudentTextbookFields): string {
    let parts: string[] = [];
    if (fields.chineseTextbook.length > 0) parts.push('语文=' + fields.chineseTextbook);
    if (fields.mathTextbook.length > 0) parts.push('数学=' + fields.mathTextbook);
    if (fields.englishTextbook.length > 0) parts.push('英语=' + fields.englishTextbook);
    if (fields.otherTextbooks.length > 0) parts.push(fields.otherTextbooks);
    return parts.join('；');
  }

  static validOtherTextbooks(value: string): boolean {
    let text = StudentTextbookProfile.clean(value);
    if (text.length === 0) return true;
    let pieces = text.split('；');
    for (let piece of pieces) {
      let item = StudentTextbookProfile.clean(piece);
      if (item.length === 0) continue;
      let separator = item.indexOf('=');
      if (separator <= 0 || separator >= item.length - 1) return false;
      if (StudentTextbookProfile.clean(item.substring(0, separator)).length === 0) return false;
      if (StudentTextbookProfile.clean(item.substring(separator + 1)).length === 0) return false;
    }
    return true;
  }

  private static empty(fields: StudentTextbookFields): boolean {
    return fields.chineseTextbook.length === 0 &&
      fields.mathTextbook.length === 0 &&
      fields.englishTextbook.length === 0 &&
      fields.otherTextbooks.length === 0;
  }

  private static afterSubject(value: string, subject: string): string {
    let result = StudentTextbookProfile.clean(value.substring(subject.length));
    while (result.indexOf('=') === 0 || result.indexOf('：') === 0 || result.indexOf(':') === 0) {
      result = StudentTextbookProfile.clean(result.substring(1));
    }
    return result;
  }

  private static clean(value: string): string {
    return value === undefined || value === null ? '' : value.trim();
  }
}
