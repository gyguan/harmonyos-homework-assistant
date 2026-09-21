import { HomeworkSourceProfileService } from '../../../application/capture/HomeworkSourceProfileService';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import {
  HomeworkSourceProfile,
  HomeworkSourceTeacherAlias
} from '../../../domain/model/HomeworkSourceProfileModels';
import { Subject } from '../../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

export interface HomeworkSourceProfileFormState {
  studentId: string;
  profileId: string;
  createdAtEpochMs: number;
  lastUsedAtEpochMs: number;
  profileName: string;
  groupTitle: string;
  startTime: string;
  chineseTeacher: string;
  chineseAliases: string;
  mathTeacher: string;
  mathAliases: string;
  englishTeacher: string;
  englishAliases: string;
}

export class HomeworkSourceProfileViewModel {
  private readonly family: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private readonly profiles: HomeworkSourceProfileService = HomeworkSourceProfileService.instance;

  load(): HomeworkSourceProfileFormState {
    let student = this.family.getStudent();
    let existing = this.profiles.getActiveProfile(student.id);
    let form: HomeworkSourceProfileFormState = {
      studentId: student.id,
      profileId: `source-profile-${student.id}`,
      createdAtEpochMs: 0,
      lastUsedAtEpochMs: 0,
      profileName: student.className.length > 0 ? student.className : '班级作业群',
      groupTitle: '',
      startTime: '15:00',
      chineseTeacher: '',
      chineseAliases: '',
      mathTeacher: '',
      mathAliases: '',
      englishTeacher: '',
      englishAliases: ''
    };
    if (existing === null) return form;

    form.profileId = existing.id;
    form.createdAtEpochMs = existing.createdAtEpochMs;
    form.lastUsedAtEpochMs = existing.lastUsedAtEpochMs;
    form.profileName = existing.name;
    form.groupTitle = existing.groupTitle;
    form.startTime = this.profiles.formatStartTime(existing);
    for (let teacher of existing.teacherAliases) this.applyTeacher(form, teacher);
    return form;
  }

  save(form: HomeworkSourceProfileFormState): HomeworkSourceProfile {
    if (this.family.getActiveStudentId() !== form.studentId) {
      throw new Error('当前孩子已切换，请返回后重新进入班级采集设置');
    }
    let startMinute = this.profiles.parseStartTime(form.startTime);
    if (startMinute < 0) throw new Error('开始时间请按 HH:mm 填写，例如 15:00');

    let teachers: HomeworkSourceTeacherAlias[] = [];
    this.appendTeacher(teachers, form.chineseTeacher, form.chineseAliases, Subject.CHINESE);
    this.appendTeacher(teachers, form.mathTeacher, form.mathAliases, Subject.MATH);
    this.appendTeacher(teachers, form.englishTeacher, form.englishAliases, Subject.ENGLISH);

    return this.profiles.save({
      id: form.profileId.length > 0 ? form.profileId : `source-profile-${form.studentId}`,
      name: form.profileName,
      groupTitle: form.groupTitle,
      studentId: form.studentId,
      teacherAliases: teachers,
      defaultStartMinuteOfDay: startMinute,
      enabled: true,
      createdAtEpochMs: form.createdAtEpochMs,
      updatedAtEpochMs: Date.now(),
      lastUsedAtEpochMs: form.lastUsedAtEpochMs
    });
  }

  private appendTeacher(target: HomeworkSourceTeacherAlias[], displayName: string,
    aliases: string, subject: Subject): void {
    let teacher = this.profiles.createTeacher(displayName, aliases, subject);
    if (teacher !== null) target.push(teacher);
  }

  private applyTeacher(form: HomeworkSourceProfileFormState,
    teacher: HomeworkSourceTeacherAlias): void {
    let aliases = teacher.aliases.join(',');
    if (teacher.subject === Subject.CHINESE) {
      form.chineseTeacher = teacher.displayName;
      form.chineseAliases = aliases;
    } else if (teacher.subject === Subject.MATH) {
      form.mathTeacher = teacher.displayName;
      form.mathAliases = aliases;
    } else if (teacher.subject === Subject.ENGLISH) {
      form.englishTeacher = teacher.displayName;
      form.englishAliases = aliases;
    }
  }
}
