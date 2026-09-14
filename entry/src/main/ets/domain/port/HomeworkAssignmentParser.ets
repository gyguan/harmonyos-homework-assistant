import { CandidateAssignment } from '../model/HomeworkModels';
import { ExtractedHomeworkText } from '../model/ImportModels';

export interface HomeworkAssignmentParser {
  parse(input: ExtractedHomeworkText): Promise<CandidateAssignment[]>;
}
