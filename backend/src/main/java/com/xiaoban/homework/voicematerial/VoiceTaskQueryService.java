package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VoiceTaskQueryService {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private static final Set<String> DISPLAY_STATUSES =
      Set.of("ACTIVE", "READY", "USED_BEFORE", "INVALID", "PROCESSING");
  private static final String STATUS_SQL = """
      case
        when p.status = 'INVALID' then 'INVALID'
        when p.status = 'UPLOADING' then 'PROCESSING'
        when a.id is not null then 'ACTIVE'
        when p.consumed_assignment_id is not null and p.consumed_assignment_id <> '' then 'USED_BEFORE'
        when p.status = 'READY' then 'READY'
        else 'PROCESSING'
      end
      """;

  private final NamedParameterJdbcTemplate jdbc;
  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final AssignmentRepository assignments;
  private final StudentService students;

  public VoiceTaskQueryService(NamedParameterJdbcTemplate jdbc,
      VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      AssignmentRepository assignments,
      StudentService students) {
    this.jdbc = jdbc;
    this.packages = packages;
    this.files = files;
    this.assignments = assignments;
    this.students = students;
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceTaskPageResponse query(UUID familyId, String studentId,
      String status, String subjectCode, String keyword, String createdFrom, String createdTo,
      int page, int size, String sort) {
    int safePage = Math.max(0, page);
    int safeSize = Math.min(100, Math.max(1, size));
    String normalizedStudent = trim(studentId);
    String normalizedStatus = trim(status).toUpperCase(Locale.ROOT);
    String normalizedSubject = trim(subjectCode).toUpperCase(Locale.ROOT);
    String normalizedKeyword = trim(keyword).toLowerCase(Locale.ROOT);

    if (!normalizedStudent.isBlank()) students.requireOwned(familyId, normalizedStudent);
    if (!normalizedStatus.isBlank() && !DISPLAY_STATUSES.contains(normalizedStatus)) {
      throw new ApiExceptions.BadRequest("不支持的语音任务状态");
    }

    StringBuilder where = new StringBuilder(" where p.family_id = :familyId ");
    MapSqlParameterSource params = new MapSqlParameterSource()
        .addValue("familyId", familyId);

    if (!normalizedStudent.isBlank()) {
      where.append(" and p.student_id = :studentId ");
      params.addValue("studentId", normalizedStudent);
    }
    if (!normalizedStatus.isBlank()) {
      where.append(" and (").append(STATUS_SQL).append(") = :displayStatus ");
      params.addValue("displayStatus", normalizedStatus);
    }
    if (!normalizedSubject.isBlank()) {
      where.append(" and p.subject_code = :subjectCode ");
      params.addValue("subjectCode", normalizedSubject);
    }
    if (!normalizedKeyword.isBlank()) {
      where.append("""
           and (
             lower(p.directory_name) like :keyword
             or lower(coalesce(a.title, '')) like :keyword
             or exists (
               select 1 from voice_material_file f
               where f.family_id = p.family_id
                 and f.package_id = p.id
                 and lower(f.relative_name) like :keyword
             )
           )
          """);
      params.addValue("keyword", "%" + normalizedKeyword + "%");
    }

    LocalDate from = parseDate(createdFrom, "任务创建开始日期");
    LocalDate to = parseDate(createdTo, "任务创建结束日期");
    if (from != null) {
      where.append(" and coalesce(a.created_at, p.consumed_at) >= :createdFrom ");
      params.addValue("createdFrom",
          Timestamp.from(from.atStartOfDay(BUSINESS_ZONE).toInstant()));
    }
    if (to != null) {
      where.append(" and coalesce(a.created_at, p.consumed_at) < :createdTo ");
      params.addValue("createdTo",
          Timestamp.from(to.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant()));
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw new ApiExceptions.BadRequest("任务创建开始日期不能晚于结束日期");
    }

    String joins = """
         from voice_material_package p
         left join assignment a
           on a.id = p.consumed_assignment_id
          and a.family_id = p.family_id
          and a.student_id = p.student_id
          and a.content_type = 'AUDIO_IMAGE'
         left join student s
           on s.id = p.student_id
          and s.family_id = p.family_id
        """;

    Long totalValue = jdbc.queryForObject(
        "select count(*) " + joins + where,
        params, Long.class);
    long total = totalValue == null ? 0L : totalValue.longValue();

    params.addValue("limit", safeSize);
    params.addValue("offset", safePage * safeSize);
    String sql = """
        select
          p.id as package_id,
          p.student_id,
          coalesce(s.name, '') as student_name,
          coalesce(a.id, '') as assignment_id,
          coalesce(a.title, '') as task_name,
          coalesce(a.status, '') as assignment_status,
          p.subject_code,
          p.directory_name,
          p.expected_minutes,
          p.error_message,
          p.created_at as imported_at,
          coalesce(a.created_at, p.consumed_at) as task_created_at,
        """ + STATUS_SQL + """
          as display_status,
          (select count(*) from voice_material_file af
            where af.family_id = p.family_id and af.package_id = p.id
              and af.resource_type = 'AUDIO') as audio_count,
          (select count(*) from voice_material_file imf
            where imf.family_id = p.family_id and imf.package_id = p.id
              and imf.resource_type = 'IMAGE') as image_count
        """ + joins + where + " order by " + orderBy(sort)
        + " limit :limit offset :offset";

    List<VoiceMaterialDtos.VoiceTaskItemResponse> items =
        jdbc.query(sql, params, this::mapItem);
    int totalPages = total == 0 ? 0 : (int) ((total + safeSize - 1) / safeSize);
    return new VoiceMaterialDtos.VoiceTaskPageResponse(
        items, safePage, safeSize, total, totalPages);
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceTaskDetailResponse detail(UUID familyId, UUID packageId) {
    VoiceMaterialPackageEntity item = packages.findById(packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    if (!familyId.equals(item.familyId)) {
      throw new ApiExceptions.NotFound("语音素材目录不存在");
    }
    StudentEntity student = students.requireOwned(familyId, item.studentId);
    AssignmentEntity assignment = activeAssignment(familyId, item);

    List<VoiceMaterialDtos.FileResponse> materialFiles =
        files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(familyId, item.id)
            .stream()
            .map(file -> new VoiceMaterialDtos.FileResponse(
                file.id.toString(), file.assetId.toString(), file.resourceType,
                file.relativeName, file.sortOrder))
            .toList();

    long audioCount = materialFiles.stream()
        .filter(file -> "AUDIO".equals(file.resourceType())).count();
    long imageCount = materialFiles.stream()
        .filter(file -> "IMAGE".equals(file.resourceType())).count();

    VoiceMaterialDtos.VoiceTaskItemResponse summary =
        new VoiceMaterialDtos.VoiceTaskItemResponse(
            item.id.toString(),
            item.studentId,
            student.name,
            assignment == null ? "" : assignment.id,
            assignment == null ? "" : assignment.title,
            assignment == null ? "" : assignment.status,
            item.subjectCode,
            item.directoryName,
            displayStatus(item, assignment),
            (int) audioCount,
            (int) imageCount,
            item.expectedMinutes,
            assignment != null && assignment.createdAt != null
                ? assignment.createdAt.toEpochMilli()
                : item.consumedAt == null ? 0L : item.consumedAt.toEpochMilli(),
            item.createdAt == null ? 0L : item.createdAt.toEpochMilli(),
            item.errorMessage == null ? "" : item.errorMessage);

    List<VoiceMaterialDtos.VoiceTaskHistoryItem> history = new ArrayList<>();
    if (item.createdAt != null) {
      history.add(new VoiceMaterialDtos.VoiceTaskHistoryItem(
          item.createdAt.toEpochMilli(), "IMPORT_COMPLETED", "文件夹导入"));
    }
    if (item.consumedAt != null) {
      history.add(new VoiceMaterialDtos.VoiceTaskHistoryItem(
          item.consumedAt.toEpochMilli(), "TASK_CREATED", "创建语音任务"));
    }
    history.sort((left, right) -> Long.compare(right.atEpochMs(), left.atEpochMs()));

    return new VoiceMaterialDtos.VoiceTaskDetailResponse(
        summary, materialFiles, history);
  }

  private VoiceMaterialDtos.VoiceTaskItemResponse mapItem(ResultSet rs, int rowNum)
      throws SQLException {
    Timestamp taskCreated = rs.getTimestamp("task_created_at");
    Timestamp imported = rs.getTimestamp("imported_at");
    return new VoiceMaterialDtos.VoiceTaskItemResponse(
        rs.getString("package_id"),
        rs.getString("student_id"),
        rs.getString("student_name"),
        rs.getString("assignment_id"),
        rs.getString("task_name"),
        rs.getString("assignment_status"),
        rs.getString("subject_code"),
        rs.getString("directory_name"),
        rs.getString("display_status"),
        rs.getInt("audio_count"),
        rs.getInt("image_count"),
        rs.getInt("expected_minutes"),
        taskCreated == null ? 0L : taskCreated.toInstant().toEpochMilli(),
        imported == null ? 0L : imported.toInstant().toEpochMilli(),
        rs.getString("error_message") == null ? "" : rs.getString("error_message"));
  }

  private AssignmentEntity activeAssignment(UUID familyId, VoiceMaterialPackageEntity item) {
    if (item.consumedAssignmentId == null || item.consumedAssignmentId.isBlank()) return null;
    AssignmentEntity assignment = assignments.findById(item.consumedAssignmentId).orElse(null);
    if (assignment == null || !familyId.equals(assignment.familyId)
        || !item.studentId.equals(assignment.studentId)
        || !"AUDIO_IMAGE".equals(assignment.contentType)) {
      return null;
    }
    return assignment;
  }

  private String displayStatus(VoiceMaterialPackageEntity item, AssignmentEntity assignment) {
    if ("INVALID".equals(item.status)) return "INVALID";
    if ("UPLOADING".equals(item.status)) return "PROCESSING";
    if (assignment != null) return "ACTIVE";
    if (item.consumedAssignmentId != null && !item.consumedAssignmentId.isBlank()) {
      return "USED_BEFORE";
    }
    if ("READY".equals(item.status)) return "READY";
    return "PROCESSING";
  }

  private LocalDate parseDate(String raw, String label) {
    String value = trim(raw);
    if (value.isBlank()) return null;
    try {
      return LocalDate.parse(value);
    } catch (RuntimeException error) {
      throw new ApiExceptions.BadRequest(label + "格式不正确");
    }
  }

  private String orderBy(String sort) {
    String normalized = trim(sort).toLowerCase(Locale.ROOT);
    return switch (normalized) {
      case "createdat,asc" ->
          "coalesce(a.created_at, p.consumed_at) asc nulls last, p.created_at asc, p.id asc";
      case "directoryname,asc" -> "p.directory_name asc, p.created_at desc, p.id asc";
      case "directoryname,desc" -> "p.directory_name desc, p.created_at desc, p.id asc";
      case "importedat,asc" -> "p.created_at asc, p.id asc";
      case "importedat,desc" -> "p.created_at desc, p.id asc";
      default ->
          "coalesce(a.created_at, p.consumed_at) desc nulls last, p.created_at desc, p.id asc";
    };
  }

  private String trim(String value) {
    return value == null ? "" : value.trim();
  }
}
