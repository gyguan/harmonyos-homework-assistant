import { ExtractedHomeworkText, HomeworkImportPipelineResult, HomeworkOrganizerMode } from '../../domain/model/ImportModels';
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

  async extract(input: RawHomeworkImport): Promise<ExtractedHomeworkText> {
    return await this.extractor.extract(input);
  }

  async parse(extracted: ExtractedHomeworkText): Promise<CandidateAssignment[]> {
    return await this.parser.parse(extracted);
  }

  async run(input: RawHomeworkImport): Promise<HomeworkImportPipelineResult> {
    let extracted: ExtractedHomeworkText = await this.extract(input);
    let candidates: CandidateAssignment[] = await this.parse(extracted);
    return {
      extracted: extracted,
      candidates: candidates,
      organizerMode: HomeworkOrganizerMode.LOCAL
    };
  }
}
