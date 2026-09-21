import {
  HomeworkSourceProfile,
  HomeworkSourceProfileSnapshot,
  HomeworkSourceTeacherAlias
} from '../../domain/model/HomeworkSourceProfileModels';
import { HomeworkSourceProfilePersistence } from '../../domain/port/HomeworkSourceProfilePersistence';

const SOURCE_PROFILE_SCHEMA_VERSION: number = 1;

export class HomeworkSourceProfileStore {
  static readonly instance: HomeworkSourceProfileStore = new HomeworkSourceProfileStore();

  private profiles: HomeworkSourceProfile[] = [];
  private persistence: HomeworkSourceProfilePersistence | null = null;
  private persistRequested: boolean = false;
  private persistRunning: boolean = false;

  private constructor() {}

  async initialize(persistence: HomeworkSourceProfilePersistence): Promise<void> {
    this.persistence = persistence;
    let snapshot = await persistence.load();
    if (snapshot === null) {
      await persistence.save(this.snapshot());
      return;
    }
    if (snapshot.schemaVersion !== SOURCE_PROFILE_SCHEMA_VERSION) {
      throw new Error(`不支持的班级采集配置版本: ${snapshot.schemaVersion}`);
    }
    this.profiles = [];
    for (let profile of snapshot.profiles) this.profiles.push(this.cloneProfile(profile));
  }

  get(profileId: string): HomeworkSourceProfile | null {
    for (let profile of this.profiles) {
      if (profile.id === profileId) return this.cloneProfile(profile);
    }
    return null;
  }

  getActive(studentId: string): HomeworkSourceProfile | null {
    let best: HomeworkSourceProfile | null = null;
    for (let profile of this.profiles) {
      if (profile.studentId !== studentId || !profile.enabled) continue;
      if (best === null || profile.updatedAtEpochMs > best.updatedAtEpochMs) best = profile;
    }
    return best === null ? null : this.cloneProfile(best);
  }

  save(profile: HomeworkSourceProfile): void {
    let copy = this.cloneProfile(profile);
    for (let current of this.profiles) {
      if (current.studentId === copy.studentId && current.id !== copy.id) current.enabled = false;
    }
    let index = this.indexOf(copy.id);
    if (index >= 0) this.profiles[index] = copy;
    else this.profiles.push(copy);
    this.requestPersist();
  }

  markUsed(profileId: string): void {
    let index = this.indexOf(profileId);
    if (index < 0) return;
    this.profiles[index].lastUsedAtEpochMs = Date.now();
    this.profiles[index].updatedAtEpochMs = Date.now();
    this.requestPersist();
  }

  private indexOf(profileId: string): number {
    for (let i = 0; i < this.profiles.length; i++) if (this.profiles[i].id === profileId) return i;
    return -1;
  }

  private cloneTeacher(source: HomeworkSourceTeacherAlias): HomeworkSourceTeacherAlias {
    return {
      displayName: source.displayName,
      aliases: source.aliases.slice(),
      subject: source.subject
    };
  }

  private cloneProfile(source: HomeworkSourceProfile): HomeworkSourceProfile {
    let teachers: HomeworkSourceTeacherAlias[] = [];
    for (let teacher of source.teacherAliases) teachers.push(this.cloneTeacher(teacher));
    return {
      id: source.id,
      name: source.name,
      groupTitle: source.groupTitle,
      studentId: source.studentId,
      teacherAliases: teachers,
      defaultStartMinuteOfDay: source.defaultStartMinuteOfDay,
      enabled: source.enabled,
      createdAtEpochMs: source.createdAtEpochMs,
      updatedAtEpochMs: source.updatedAtEpochMs,
      lastUsedAtEpochMs: source.lastUsedAtEpochMs
    };
  }

  private snapshot(): HomeworkSourceProfileSnapshot {
    let profiles: HomeworkSourceProfile[] = [];
    for (let profile of this.profiles) profiles.push(this.cloneProfile(profile));
    return {
      schemaVersion: SOURCE_PROFILE_SCHEMA_VERSION,
      profiles: profiles
    };
  }

  private requestPersist(): void {
    if (this.persistence === null) return;
    this.persistRequested = true;
    if (!this.persistRunning) void this.flushPersistQueue();
  }

  private async flushPersistQueue(): Promise<void> {
    let persistence = this.persistence;
    if (persistence === null || this.persistRunning) return;
    this.persistRunning = true;
    while (this.persistRequested) {
      this.persistRequested = false;
      await persistence.save(this.snapshot());
    }
    this.persistRunning = false;
  }
}
