import { AppTheme } from './AppTheme';
import { Subject } from '../../domain/model/HomeworkModels';

/**
 * Subject → accent color.
 *
 * Subjects come from the backend whitelist, so this stays an exhaustive switch instead of a keyword
 * guess: a new subject must be added here deliberately rather than silently borrowing a neighbour's
 * color. Activity subjects keep the success tone and interest keeps warning, matching the original
 * student home mapping that this palette replaces.
 */
export class SubjectPalette {
  static accent(subject: Subject): string {
    switch (subject) {
      case Subject.CHINESE:
        return AppTheme.SUBJECT_CHINESE;
      case Subject.MATH:
        return AppTheme.SUBJECT_MATH;
      case Subject.ENGLISH:
        return AppTheme.SUBJECT_ENGLISH;
      case Subject.SPORTS:
      case Subject.PRACTICE:
        return AppTheme.SUCCESS;
      case Subject.INTEREST:
        return AppTheme.WARNING;
      default:
        return AppTheme.SUBJECT_OTHER;
    }
  }

  static soft(subject: Subject): string {
    switch (subject) {
      case Subject.CHINESE:
        return AppTheme.SUBJECT_CHINESE_SOFT;
      case Subject.MATH:
        return AppTheme.SUBJECT_MATH_SOFT;
      case Subject.ENGLISH:
        return AppTheme.SUBJECT_ENGLISH_SOFT;
      case Subject.SPORTS:
      case Subject.PRACTICE:
        return AppTheme.SUCCESS_SOFT;
      case Subject.INTEREST:
        return AppTheme.WARNING_SOFT;
      default:
        return AppTheme.SUBJECT_OTHER_SOFT;
    }
  }

  /** Single-character badge used by compact list rows and task cards. */
  static initial(subject: Subject): string {
    const label: string = `${subject}`;
    return label.length > 0 ? label.substring(0, 1) : '作';
  }
}
