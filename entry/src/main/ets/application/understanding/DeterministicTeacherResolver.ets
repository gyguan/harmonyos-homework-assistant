import {
  HomeworkUnderstandingConfig,
  TeacherDirectoryEntry,
  TeacherResolution,
  TeacherResolutionStatus
} from '../../domain/model/HomeworkUnderstandingModels';
import { Subject } from '../../domain/model/HomeworkModels';

export class DeterministicTeacherResolver {
  resolve(sender: string, config: HomeworkUnderstandingConfig): TeacherResolution {
    let normalized = this.normalize(sender);
    if (normalized.length === 0) return this.unknown();

    for (let entry of config.teacherDirectory) {
      if (this.matchesEntry(normalized, entry)) {
        return {
          status: TeacherResolutionStatus.RESOLVED,
          teacherId: entry.teacherId,
          displayName: entry.displayName,
          subject: entry.subject
        };
      }
    }
    return this.unknown();
  }

  private matchesEntry(normalizedSender: string, entry: TeacherDirectoryEntry): boolean {
    if (this.normalize(entry.displayName) === normalizedSender) return true;
    for (let alias of entry.aliases) {
      if (this.normalize(alias) === normalizedSender) return true;
    }
    return false;
  }

  private unknown(): TeacherResolution {
    return {
      status: TeacherResolutionStatus.UNKNOWN,
      teacherId: '',
      displayName: '',
      subject: null
    };
  }

  private normalize(value: string): string {
    return value.trim().replace(/\s+/g, '').toLowerCase();
  }
}
