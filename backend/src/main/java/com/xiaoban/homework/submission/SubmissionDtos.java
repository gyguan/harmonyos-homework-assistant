package com.xiaoban.homework.submission;

import com.xiaoban.homework.assignment.AssignmentDtos;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SubmissionDtos {
  private SubmissionDtos() {}

  public record Resource(
      UUID id,
      String resourceType,
      String originalName,
      String contentType,
      long sizeBytes,
      long durationMs,
      int sortOrder,
      String downloadPath) {}

  public record Response(
      UUID id,
      String assignmentId,
      Instant submittedAt,
      List<Resource> resources,
      List<Resource> photos) {}

  public record CreateResponse(Response submission, AssignmentDtos.Response assignment) {}
}
