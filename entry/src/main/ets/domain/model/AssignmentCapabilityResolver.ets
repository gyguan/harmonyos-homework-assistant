import { Assignment, AssignmentContentType } from './HomeworkModels';
import { AssignmentCapability } from './AssignmentCapability';

/**
 * Backward compatible mapping from legacy contentType to capability model.
 * Existing AUDIO_IMAGE assignments keep working while the domain model evolves.
 */
export class AssignmentCapabilityResolver {
  static resolve(assignment: Assignment): AssignmentCapability {
    switch (assignment.contentType) {
      case AssignmentContentType.AUDIO_IMAGE:
        return {
          imageViewer: true,
          audioPlayer: true,
          videoPlayer: false,
          recorder: false,
          speechRecognition: false,
          aiEvaluation: false
        };
      default:
        return {
          imageViewer: false,
          audioPlayer: false,
          videoPlayer: false,
          recorder: false,
          speechRecognition: false,
          aiEvaluation: false
        };
    }
  }
}
