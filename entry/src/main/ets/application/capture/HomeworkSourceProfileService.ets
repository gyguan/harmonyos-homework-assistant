import { HomeworkSourceProfileStore } from '../../data/local/HomeworkSourceProfileStore';
import {
  HomeworkSourceProfile,
  HomeworkSourceTeacherAlias
} from '../../domain/model/HomeworkSourceProfileModels';
import {
  HomeworkUnderstandingConfig,
  TeacherDirectoryEntry
} from '../../domain/model/HomeworkUnderstandingModels';
import { Subject } from '../../domain/model/HomeworkModels';

export class HomeworkSourceProfileService {
  static readonly instance: HomeworkSourceProfileService = new HomeworkSourceProfileService();
  private readonly store: HomeworkSourceProfileStore = HomeworkSourceProfileStore.instance;
  private constructor() {}

  getActiveProfile(studentId: string): HomeworkSourceProfile | null {
    return this.store.getActive(studentId);
  }

  getProfile(profileId: string): HomeworkSourceProfile | null {
    return this.store.get(profileId);
  }

  save(profile: HomeworkSourceProfile): HomeworkSourceProfile {
    this.validate(profile);
    let now = Date.now();
    let saved: HomeworkSourceProfile = {
      id: profile.id,
      name: profile.name.trim(),
      groupTitle: profile.groupTitle.trim(),
      studentId: profile.studentId,
      teacherAliases: this.cloneTeachers(profile.teacherAliases),
      defaultStartMinuteOfDay: profile.defaultStartMinuteOfDay,
      enabled: true,
      createdAtEpochMs: profile.createdAtEpochMs > 0 ? profile.createdAtEpochMs : now,
      updatedAtEpochMs: now,
      lastUsedAtEpochMs: profile.lastUsedAtEpochMs
    };
    this.store.save(saved);
    return saved;
  }

  markUsed(profileId: string): void {
    this.store.markUsed(profileId);
  }

  understandingConfig(profile: HomeworkSourceProfile): HomeworkUnderstandingConfig {
    let teacherDirectory: TeacherDirectoryEntry[] = [];
    for (let teacher of profile.teacherAliases) {
      teacherDirectory.push({
        teacherId: `${profile.id}-teacher-${teacherDirectory.length + 1}`,
        displayName: teacher.displayName,
        aliases: teacher.aliases.slice(),
        subject: teacher.subject
      });
    }
    return { teacherDirectory: teacherDirectory };
  }

  formatStartTime(profile: HomeworkSourceProfile): string {
    let hour = Math.floor(profile.defaultStartMinuteOfDay / 60);
    let minute = profile.defaultStartMinuteOfDay % 60;
    return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
  }

  parseStartTime(value: string): number {
    let match = value.trim().match(/^([01]?\d|2[0-3]):([0-5]\d)$/);
    if (match === null) return -1;
    return Number(match[1]) * 60 + Number(match[2]);
  }

  normalizedAliases(displayName: string, aliasesText: string): string[] {
    let result: string[] = [];
    let values = aliasesText.replace(/，/g, ',').split(',');
    for (let value of values) {
      let normalized = value.trim();
      if (normalized.length === 0 || normalized === displayName.trim()) continue;
      if (result.indexOf(normalized) < 0) result.push(normalized);
    }
    return result;
  }

  createTeacher(displayName: string, aliasesText: string, subject: Subject): HomeworkSourceTeacherAlias | null {
    let name = displayName.trim();
    if (name.length === 0) return null;
    return {
      displayName: name,
      aliases: this.normalizedAliases(name, aliasesText),
      subject: subject
    };
  }

  private validate(profile: HomeworkSourceProfile): void {
    if (profile.studentId.length === 0) throw new Error('缺少孩子信息');
    if (profile.name.trim().length === 0) throw new Error('请填写班级名称');
    if (profile.groupTitle.trim().length === 0) throw new Error('请填写微信目标群名称');
    if (profile.defaultStartMinuteOfDay < 0 || profile.defaultStartMinuteOfDay >= 24 * 60) {
      throw new Error('默认抓取开始时间无效');
    }
    if (profile.teacherAliases.length === 0) throw new Error('至少配置一位老师');
  }

  private cloneTeachers(values: HomeworkSourceTeacherAlias[]): HomeworkSourceTeacherAlias[] {
    let result: HomeworkSourceTeacherAlias[] = [];
    for (let value of values) {
      result.push({
        displayName: value.displayName.trim(),
        aliases: value.aliases.slice(),
        subject: value.subject
      });
    }
    return result;
  }
}
