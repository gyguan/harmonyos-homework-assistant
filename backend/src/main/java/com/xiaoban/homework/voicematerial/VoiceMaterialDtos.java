package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentDtos;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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

  public record CompleteResponse(String id, String studentId, int directoryCount,
      int readyCount, int invalidCount, List<PackageResult> packages) {
    static CompleteResponse from(VoiceMaterialBatchEntity entity, List<PackageResult> packages) {
      return new CompleteResponse(entity.id.toString(), entity.studentId, entity.directoryCount,
          entity.readyCount, entity.invalidCount, packages);
    }
  }

  public record PackageResult(String id, String batchId, String directoryName,
      String subjectCode, int expectedMinutes, int audioCount, int imageCount,
      String status, String errorMessage) {}

  public record RegisterPackageRequest(
      @NotBlank @Size(max = 300) String directoryName,
      @NotBlank @Size(max = 64) String subjectCode,
      @Size(max = 300) String title,
      @Min(1) @Max(240) Integer expectedMinutes,
      Long dueAtEpochMs,
      @Size(max = 32) String assignmentType) {}

  public record PackageResponse(String id, String batchId, String studentId,
      String directoryName, String subjectCode, String title, int expectedMinutes,
      long dueAtEpochMs, String assignmentType, String status, String errorMessage,
      String consumedAssignmentId, boolean hasCreatedBefore, boolean hasActiveAssignment,
      long consumedAtEpochMs, List<FileResponse> files) {}

  public record FileResponse(String id, String assetId, String resourceType,
      String relativeName, int sortOrder) {}

  public record VoiceTaskPageResponse(List<VoiceTaskItemResponse> items,
      int page, int size, long totalElements, int totalPages) {}

  public record VoiceTaskItemResponse(
      String assignmentId,
      String taskName,
      String assignmentStatus,
      String studentId,
      String studentName,
      String subjectCode,
      int expectedMinutes,
      long taskCreatedAtEpochMs,
      String packageId,
      String directoryName) {}

  public record VoiceTaskDetailResponse(
      VoiceTaskItemResponse item,
      List<FileResponse> files) {}

  public record VoiceFolderPageResponse(List<VoiceFolderItemResponse> items,
      int page, int size, long totalElements, int totalPages) {}

  public record VoiceFolderItemResponse(
      String packageId,
      String directoryName,
      String folderStatus,
      String studentId,
      String studentName,
      String subjectCode,
      int expectedMinutes,
      int audioCount,
      int imageCount,
      long usageCount,
      long activeTaskCount,
      long lastUsedAtEpochMs,
      long importedAtEpochMs,
      String errorMessage) {}

  public record VoiceFolderTaskHistoryItem(
      String assignmentId,
      String taskName,
      String assignmentStatus,
      long createdAtEpochMs,
      boolean assignmentExists) {}

  public record VoiceFolderDetailResponse(
      VoiceFolderItemResponse item,
      List<FileResponse> files,
      List<VoiceFolderTaskHistoryItem> recentTasks) {}

  public record CreateAssignmentRequest(
      @NotBlank @Size(max = 80) String studentId,
      @Min(1) @Max(240) Integer expectedMinutes,
      Long dueAtEpochMs,
      @Size(max = 32) String dueText,
      @Size(max = 300) String title,
      @Size(max = 1000) String instruction,
      @Size(max = 120) String requestId) {}

  public record CreateAssignmentResponse(boolean created, String assignmentId,
      AssignmentDtos.Response assignment) {}

  public record AutoCreateResponse(boolean created, String businessDate,
      String packageId, String assignmentId, AssignmentDtos.Response assignment) {}
}
