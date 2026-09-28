import {
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticePaper
} from '../model/practice/PracticeModels';

export interface PracticeGenerationRepository {
  generate(studentId: string, input: PracticeGenerationRequest): Promise<PracticeGenerationResult>;
  get(generationId: string): Promise<PracticeGenerationResult>;
  publish(generationId: string): Promise<PracticePaper>;
}
