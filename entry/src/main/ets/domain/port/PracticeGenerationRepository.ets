import {
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticePublishPurpose,
  PracticePublishResult,
  PracticePublishScope
} from '../model/practice/PracticeModels';

export interface PracticeGenerationRepository {
  generate(studentId: string, input: PracticeGenerationRequest): Promise<PracticeGenerationResult>;
  get(generationId: string): Promise<PracticeGenerationResult>;
  publish(
    generationId: string,
    scope: PracticePublishScope,
    targetStudentIds: string[],
    purpose?: PracticePublishPurpose
  ): Promise<PracticePublishResult>;
}
