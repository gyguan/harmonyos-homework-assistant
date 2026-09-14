import { MockData } from '../../data/MockData';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { CandidateAssignment } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';

export class MockHomeworkAssignmentParser implements HomeworkAssignmentParser {
  async parse(input: ExtractedHomeworkText): Promise<CandidateAssignment[]> {
    let result: CandidateAssignment[] = [];
    for (let candidate of MockData.candidates) {
      result.push({
        id: candidate.id,
        studentId: input.studentId,
        subject: candidate.subject,
        title: candidate.title,
        instruction: candidate.instruction,
        textbookRef: candidate.textbookRef,
        dueText: candidate.dueText,
        sourceEvidence: {
          sourceLabel: input.sourceLabel,
          excerpt: candidate.sourceEvidence.excerpt
        },
        confidence: candidate.confidence
      });
    }
    return result;
  }
}
