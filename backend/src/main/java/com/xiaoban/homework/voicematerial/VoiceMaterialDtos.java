package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentDtos;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;

public final class VoiceMaterialDtos {
  private VoiceMaterialDtos() {}

  public record BatchResponse(String id, String studentId, int directoryCount,
      int readyCount, int invalidCount) {
    static BatchResponse from(VoiceMaterialBatchEntity entity) {
      return new BatchResponse(entity.id.toString(), entity.studentId, entity.directoryCount,
          entity.readyCount, entity.invalidCount);
    }
  }

  public record RegisterPackageRequest(
      @NotBlank String directoryName,
      @NotBlank String subjectCode,
      String title,
      @Min(1) @Max(240) Integer expectedMinutes,
      Long dueAtEpochMs,
      String assignmentType) {}

  public record PackageResponse(String id, String batchId, String studentId,
      String directoryName, String subjectCode, String title, int expectedMinutes,
      long dueAtEpochMs, String assignmentType, String status, String errorMessage,
      String consumedAssignmentId, List<FileResponse> files) {}

  public record FileResponse(String id, String assetId, String resourceType,
      String relativeName, int sortOrder) {}

  public record CreateAssignmentResponse(boolean created, String assignmentId,
      AssignmentDtos.Response assignment) {}

  public record AutoCreateResponse(boolean created, String businessDate,
      String packageId, String assignmentId, AssignmentDtos.Response assignment) {}
}
