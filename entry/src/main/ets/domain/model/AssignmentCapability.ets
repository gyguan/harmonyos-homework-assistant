export interface AssignmentCapability {
  imageViewer: boolean;
  audioPlayer: boolean;
  videoPlayer: boolean;
  recorder: boolean;
  speechRecognition: boolean;
  aiEvaluation: boolean;
}

export const DEFAULT_ASSIGNMENT_CAPABILITY: AssignmentCapability = {
  imageViewer: false,
  audioPlayer: false,
  videoPlayer: false,
  recorder: false,
  speechRecognition: false,
  aiEvaluation: false
};

export const AUDIO_IMAGE_ASSIGNMENT_CAPABILITY: AssignmentCapability = {
  imageViewer: true,
  audioPlayer: true,
  videoPlayer: false,
  recorder: false,
  speechRecognition: false,
  aiEvaluation: false
};

export function resolveAssignmentCapability(contentType: string): AssignmentCapability {
  if (contentType === 'AUDIO_IMAGE') {
    return AUDIO_IMAGE_ASSIGNMENT_CAPABILITY;
  }
  return DEFAULT_ASSIGNMENT_CAPABILITY;
}
