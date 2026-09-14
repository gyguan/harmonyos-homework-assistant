import { RawHomeworkImport } from '../model/HomeworkModels';
import { ExtractedHomeworkText } from '../model/ImportModels';

export interface HomeworkTextExtractor {
  extract(input: RawHomeworkImport): Promise<ExtractedHomeworkText>;
}
