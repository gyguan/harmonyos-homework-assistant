import { ExtractedHomeworkText, HomeworkImportPipelineResult } from '../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';

export class HomeworkImportPipeline {
  private readonly extractor: HomeworkTextExtractor;
  private readonly parser: HomeworkAssignmentParser;

  constructor(extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser) {
    this.extractor = extractor;
    this.parser = parser;
  }

  async run(input: RawHomeworkImport): Promise<HomeworkImportPipelineResult> {
    let extracted: ExtractedHomeworkText = await this.extractor.extract(input);
    let candidates: CandidateAssignment[] = await this.parser.parse(extracted);
    return {
      extracted: extracted,
      candidates: candidates
    };
  }
}
