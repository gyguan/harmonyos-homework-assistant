import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';

export class MockHomeworkTextExtractor implements HomeworkTextExtractor {
  async extract(input: RawHomeworkImport): Promise<ExtractedHomeworkText> {
    return {
      importId: input.id,
      familyId: input.familyId,
      sourceLabel: input.sourceLabel,
      text: input.rawText
    };
  }
}
