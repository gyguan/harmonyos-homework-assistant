import { HomeworkSourceProfileService } from '../../../application/capture/HomeworkSourceProfileService';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { HomeworkSourceProfile } from '../../../domain/model/HomeworkSourceProfileModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

export class HomeworkCaptureHomeViewModel {
  private readonly family: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private readonly profiles: HomeworkSourceProfileService = HomeworkSourceProfileService.instance;

  private activeProfile(): HomeworkSourceProfile | null {
    return this.profiles.getActiveProfile(this.family.getActiveStudentId());
  }

  hasSourceProfile(): boolean {
    return this.activeProfile() !== null;
  }

  profileName(): string {
    let profile = this.activeProfile();
    return profile === null ? '尚未配置班级来源' : profile.name;
  }

  groupTitle(): string {
    let profile = this.activeProfile();
    return profile === null ? '首次使用请先配置目标微信群' : profile.groupTitle;
  }

  teacherSummary(): string {
    let profile = this.activeProfile();
    if (profile === null || profile.teacherAliases.length === 0) return '尚未配置老师';
    let values: string[] = [];
    for (let teacher of profile.teacherAliases) {
      values.push(`${teacher.subject} · ${teacher.displayName}`);
    }
    return values.join('  /  ');
  }

  timeWindow(): string {
    let profile = this.activeProfile();
    if (profile === null) return '配置后按今天的时间范围抓取';
    return `今天 ${this.profiles.formatStartTime(profile)} 至现在`;
  }
}
