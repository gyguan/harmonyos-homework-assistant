package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentDtos;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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
      @Size(max = 32) String assignmentType) {}

  public record PackageResponse(String id, String batchId, String studentId,
      String directoryName, String subjectCode, String title, int expectedMinutes,
      String assignmentType, String status, String errorMessage,
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
      @Size(max = 64) String subjectCode,
      @Min(1) @Max(240) Integer expectedMinutes,
      @Size(max = 10) String taskDate,
      @Size(max = 300) String title,
      @Size(max = 1000) String instruction,
      @Size(max = 120) String requestId) {}

  public record CreateAssignmentResponse(boolean created, String assignmentId,
      AssignmentDtos.Response assignment) {}

  public record AutoCreateResponse(boolean created, String businessDate,
      String packageId, String assignmentId, AssignmentDtos.Response assignment) {}

  /**
   * 管理台批量删除请求。调用方必须显式给出要删除的 id，服务端不接受"按条件全删"，
   * 以免筛选条件写错时一次清空整个家庭的素材。
   */
  public record BatchDeleteRequest(
      @NotNull(message = "请提供要删除的 id 列表")
      @Size(min = 1, max = 500, message = "一次最多删除 500 项")
      List<String> ids) {}

  public record BatchDeleteItem(String id, String label, boolean deleted, String reason) {}

  public record BatchDeleteResponse(int requested, int deleted, int skipped,
      List<BatchDeleteItem> items) {
    static BatchDeleteResponse of(int requested, List<BatchDeleteItem> items) {
      int deleted = (int) items.stream().filter(BatchDeleteItem::deleted).count();
      return new BatchDeleteResponse(requested, deleted, requested - deleted, items);
    }
  }
}
