import { BackendSession } from '../../application/remote/BackendSession';
import { PracticeGenerationRemoteApi } from '../../application/remote/PracticeGenerationRemoteApi';
import {
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticePaper
} from '../../domain/model/practice/PracticeModels';
import { PracticeGenerationRepository } from '../../domain/port/PracticeGenerationRepository';

export class DefaultPracticeGenerationRepository implements PracticeGenerationRepository {
  static readonly instance: DefaultPracticeGenerationRepository =
    new DefaultPracticeGenerationRepository(PracticeGenerationRemoteApi.instance);

  private readonly remote: PracticeGenerationRemoteApi;

  constructor(remote: PracticeGenerationRemoteApi) {
    this.remote = remote;
  }

  generate(studentId: string, input: PracticeGenerationRequest): Promise<PracticeGenerationResult> {
    this.requireConnected();
    return this.remote.generate(studentId, input);
  }

  get(generationId: string): Promise<PracticeGenerationResult> {
    this.requireConnected();
    return this.remote.get(generationId);
  }

  publish(generationId: string): Promise<PracticePaper> {
    this.requireConnected();
    return this.remote.publish(generationId);
  }

  private requireConnected(): void {
    if (!BackendSession.instance.isConnected()) {
      throw new Error('连接家庭云端后才能使用AI生成练习');
    }
  }
}
