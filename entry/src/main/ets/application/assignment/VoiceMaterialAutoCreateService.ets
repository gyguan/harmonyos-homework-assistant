import { BackendSession } from '../remote/BackendSession';
import { RemoteVoiceMaterialApi } from '../remote/RemoteVoiceMaterialApi';
import { RemoteAssignmentMapper } from '../remote/RemoteModels';
import { DefaultAssignmentRepository } from '../../data/repository/DefaultAssignmentRepository';

export class VoiceMaterialAutoCreateService {
  static readonly instance: VoiceMaterialAutoCreateService =
    new VoiceMaterialAutoCreateService();

  private constructor() {}

  async checkToday(studentId: string): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      let result = await RemoteVoiceMaterialApi.instance.autoCreateNext(studentId);
      if (!result.created || result.assignment === null) return false;

      let repository = DefaultAssignmentRepository.instance;
      let existing = repository.getCached(result.assignment.id);
      repository.applyAuthoritative(
        RemoteAssignmentMapper.toLocal(result.assignment, existing));
      return true;
    } catch {
      // Daily auto-create is best-effort on role entry. A failed check must never block
      // the student from opening cached assignments; the following repository sync can
      // recover a task that the server committed before a network response was lost.
      return false;
    }
  }
}
