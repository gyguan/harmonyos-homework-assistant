import { HomeworkSourceProfileService } from '../../../application/capture/HomeworkSourceProfileService';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

export class HomeworkImportRouteViewModel {
  private readonly family: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private readonly profiles: HomeworkSourceProfileService = HomeworkSourceProfileService.instance;

  hasSourceProfile(): boolean {
    return this.profiles.getActiveProfile(this.family.getActiveStudentId()) !== null;
  }

  profileSubtitle(): string {
    let profile = this.profiles.getActiveProfile(this.family.getActiveStudentId());
    if (profile === null) return '首次使用先配置班级群、老师和抓取时间';
    return `${profile.groupTitle} · 今天 ${this.profiles.formatStartTime(profile)} 至现在`;
  }
}
