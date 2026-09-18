package com.xiaoban.homework.assignment;

import java.util.List;

public final class AssignmentResourceDtos {
  private AssignmentResourceDtos() {}

  public record Response(String id, String resourceType, String originalName, String contentType,
      long sizeBytes, int sortOrder, long durationMs, String downloadPath) {
    static Response from(AssignmentResourceEntity entity) {
      return new Response(entity.id.toString(), entity.resourceType, entity.originalName,
          entity.contentType, entity.sizeBytes, entity.sortOrder, entity.durationMs,
          "/api/v1/assignment-resources/" + entity.id);
    }
  }

  public record VoiceCreateResponse(AssignmentDtos.Response assignment, List<Response> resources) {}
}
