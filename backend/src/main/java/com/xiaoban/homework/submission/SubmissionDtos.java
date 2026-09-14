package com.xiaoban.homework.submission;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SubmissionDtos {
  private SubmissionDtos() {}
  public record Photo(UUID id, String originalName, String contentType, long sizeBytes, String downloadPath) {}
  public record Response(UUID id, String assignmentId, Instant submittedAt, List<Photo> photos) {}
}
