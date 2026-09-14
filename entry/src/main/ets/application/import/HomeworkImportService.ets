import { HomeworkStore } from '../../data/HomeworkStore';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';
import { HomeworkImportPipeline } from './HomeworkImportPipeline';

export class HomeworkImportService {
  static readonly instance: HomeworkImportService = new HomeworkImportService();

  private pipeline: HomeworkImportPipeline | null = null;

  private constructor() {}

  configure(extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser): void {
    this.pipeline = new HomeworkImportPipeline(extractor, parser);
  }

  async reparseCurrentImport(): Promise<number> {
    if (this.pipeline === null) {
      return 0;
    }
    let candidates = await this.pipeline.run(HomeworkStore.instance.getRawImport());
    HomeworkStore.instance.replaceCandidates(candidates);
    return candidates.length;
  }
}
