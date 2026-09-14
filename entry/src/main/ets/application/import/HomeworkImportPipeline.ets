import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
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

  async run(input: RawHomeworkImport): Promise<CandidateAssignment[]> {
    let extracted: ExtractedHomeworkText = await this.extractor.extract(input);
    return await this.parser.parse(extracted);
  }
}
