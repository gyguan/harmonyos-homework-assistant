package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.ZoneId;
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
  private static final Set<String> FOLDER_STATUSES =
      Set.of("READY", "INVALID", "PROCESSING", "ARCHIVED");
  private static final Set<String> USAGE_FILTERS =
      Set.of("UNUSED", "USED", "ALL");

  private final NamedParameterJdbcTemplate jdbc;
  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final StudentService students;

  public VoiceTaskQueryService(NamedParameterJdbcTemplate jdbc,
      VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      StudentService students) {
    this.jdbc = jdbc;
    this.packages = packages;
    this.files = files;
    this.students = students;
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceTaskPageResponse queryTasks(UUID familyId, String studentId,
      String status, String subjectCode, String keyword, String createdFrom, String createdTo,
      String packageId, int page, int size, String sort) {
    int safePage = Math.max(0, page);
    int safeSize = Math.min(100, Math.max(1, size));
    String normalizedStudent = trim(studentId);
    String normalizedStatus = trim(status).toUpperCase(Locale.ROOT);
    String normalizedSubject = trim(subjectCode).toUpperCase(Locale.ROOT);
    String normalizedKeyword = trim(keyword).toLowerCase(Locale.ROOT);
    String normalizedPackageId = trim(packageId);

    if (!normalizedStudent.isBlank()) students.requireOwned(familyId, normalizedStudent);

    StringBuilder where = new StringBuilder(
        " where a.family_id = :familyId and a.content_type = 'AUDIO_IMAGE' ");
    MapSqlParameterSource params = new MapSqlParameterSource().addValue("familyId", familyId);

    if (!normalizedStudent.isBlank()) {
      where.append(" and a.student_id = :studentId ");
      params.addValue("studentId", normalizedStudent);
    }
    if (!normalizedStatus.isBlank()) {
      where.append(" and a.status = :taskStatus ");
      params.addValue("taskStatus", normalizedStatus);
    }
    if (!normalizedSubject.isBlank()) {
      where.append(" and a.subject_code = :subjectCode ");
      params.addValue("subjectCode", normalizedSubject);
    }
    if (!normalizedPackageId.isBlank()) {
      try {
        params.addValue("packageId", UUID.fromString(normalizedPackageId));
      } catch (IllegalArgumentException error) {
        throw new ApiExceptions.BadRequest("来源文件夹 ID 格式不正确");
      }
      where.append(" and l.package_id = :packageId ");
    }
    if (!normalizedKeyword.isBlank()) {
      where.append("""
           and (
             lower(a.title) like :keyword
             or lower(coalesce(p.directory_name, '本地上传')) like :keyword
           )
          """);
      params.addValue("keyword", "%" + normalizedKeyword + "%");
    }

    LocalDate from = parseDate(createdFrom, "任务创建开始日期");
    LocalDate to = parseDate(createdTo, "任务创建结束日期");
    if (from != null && to != null && from.isAfter(to)) {
      throw new ApiExceptions.BadRequest("任务创建开始日期不能晚于结束日期");
    }
    if (from != null) {
      where.append(" and a.created_at >= :createdFrom ");
      params.addValue("createdFrom", Timestamp.from(from.atStartOfDay(BUSINESS_ZONE).toInstant()));
    }
    if (to != null) {
      where.append(" and a.created_at < :createdTo ");
      params.addValue("createdTo",
          Timestamp.from(to.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant()));
    }

    String joins = """
        from assignment a
        join student s
          on s.id = a.student_id
         and s.family_id = a.family_id
        left join voice_material_task_link l
          on l.assignment_id = a.id
         and l.family_id = a.family_id
        left join voice_material_package p
          on p.id = l.package_id
         and p.family_id = a.family_id
        """;

    Long totalValue = jdbc.queryForObject(
        "select count(*) " + joins + where, params, Long.class);
    long total = totalValue == null ? 0L : totalValue.longValue();

    params.addValue("limit", safeSize);
    params.addValue("offset", safePage * safeSize);
    String sql = """
        select
          a.id as assignment_id,
          a.title as task_name,
          a.status as assignment_status,
          a.student_id,
          s.name as student_name,
          a.subject_code,
          a.expected_minutes,
          a.created_at as task_created_at,
          p.id as package_id,
          p.directory_name
        """ + joins + where + " order by " + taskOrder(sort)
        + " limit :limit offset :offset";

    List<VoiceMaterialDtos.VoiceTaskItemResponse> items =
        jdbc.query(sql, params, this::mapTask);
    int totalPages = total == 0 ? 0 : (int) ((total + safeSize - 1) / safeSize);
    return new VoiceMaterialDtos.VoiceTaskPageResponse(
        items, safePage, safeSize, total, totalPages);
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceTaskDetailResponse taskDetail(
      UUID familyId, String assignmentId) {
    MapSqlParameterSource params = new MapSqlParameterSource()
        .addValue("familyId", familyId)
        .addValue("assignmentId", assignmentId);
    String sql = """
        select
          a.id as assignment_id,
          a.title as task_name,
          a.status as assignment_status,
          a.student_id,
          s.name as student_name,
          a.subject_code,
          a.expected_minutes,
          a.created_at as task_created_at,
          p.id as package_id,
          p.directory_name
        from assignment a
        join student s
          on s.id = a.student_id and s.family_id = a.family_id
        left join voice_material_task_link l
          on l.assignment_id = a.id and l.family_id = a.family_id
        left join voice_material_package p
          on p.id = l.package_id and p.family_id = a.family_id
        where a.family_id = :familyId
          and a.id = :assignmentId
          and a.content_type = 'AUDIO_IMAGE'
        """;
    List<VoiceMaterialDtos.VoiceTaskItemResponse> found = jdbc.query(sql, params, this::mapTask);
    if (found.isEmpty()) throw new ApiExceptions.NotFound("语音任务不存在");
    VoiceMaterialDtos.VoiceTaskItemResponse item = found.get(0);

    List<VoiceMaterialDtos.FileResponse> materialFiles = jdbc.query("""
        select id, asset_id, resource_type, original_name, sort_order
        from assignment_resource
        where family_id = :familyId and assignment_id = :assignmentId
        order by sort_order asc, created_at asc
        """, params, (rs, rowNum) -> new VoiceMaterialDtos.FileResponse(
            rs.getString("id"),
            rs.getString("asset_id") == null ? "" : rs.getString("asset_id"),
            rs.getString("resource_type"),
            rs.getString("original_name"),
            rs.getInt("sort_order")));
    return new VoiceMaterialDtos.VoiceTaskDetailResponse(item, materialFiles);
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceFolderPageResponse queryFolders(UUID familyId, String studentId,
      String status, String subjectCode, String keyword, String importedFrom, String importedTo,
      String usage, int page, int size, String sort) {
    int safePage = Math.max(0, page);
    int safeSize = Math.min(100, Math.max(1, size));
    String normalizedStudent = trim(studentId);
    String normalizedStatus = trim(status).toUpperCase(Locale.ROOT);
    String normalizedSubject = trim(subjectCode).toUpperCase(Locale.ROOT);
    String normalizedKeyword = trim(keyword).toLowerCase(Locale.ROOT);
    String normalizedUsage = trim(usage).toUpperCase(Locale.ROOT);
    if (normalizedUsage.isBlank()) normalizedUsage = "ALL";

    if (!normalizedStudent.isBlank()) students.requireOwned(familyId, normalizedStudent);
    if (!normalizedStatus.isBlank() && !FOLDER_STATUSES.contains(normalizedStatus)) {
      throw new ApiExceptions.BadRequest("不支持的语音文件夹状态");
    }
    if (!USAGE_FILTERS.contains(normalizedUsage)) {
      throw new ApiExceptions.BadRequest("不支持的语音文件夹使用筛选");
    }

    String usageSql = "(select count(*) from voice_material_task_link ul"
        + " where ul.family_id = p.family_id and ul.package_id = p.id)";
    StringBuilder where = new StringBuilder(" where p.family_id = :familyId ");
    MapSqlParameterSource params = new MapSqlParameterSource().addValue("familyId", familyId);

    if (!normalizedStudent.isBlank()) {
      where.append(" and p.student_id = :studentId ");
      params.addValue("studentId", normalizedStudent);
    }
    if (!normalizedStatus.isBlank()) {
      where.append(" and ").append(folderStatusSql()).append(" = :folderStatus ");
      params.addValue("folderStatus", normalizedStatus);
    }
    if (!normalizedSubject.isBlank()) {
      where.append(" and p.subject_code = :subjectCode ");
      params.addValue("subjectCode", normalizedSubject);
    }
    if (!normalizedKeyword.isBlank()) {
      where.append("""
           and (
             lower(p.directory_name) like :keyword
             or exists (
               select 1 from voice_material_file vf
               where vf.family_id = p.family_id
                 and vf.package_id = p.id
                 and lower(vf.relative_name) like :keyword
             )
           )
          """);
      params.addValue("keyword", "%" + normalizedKeyword + "%");
    }
    if ("UNUSED".equals(normalizedUsage)) where.append(" and ").append(usageSql).append(" = 0 ");
    if ("USED".equals(normalizedUsage)) where.append(" and ").append(usageSql).append(" > 0 ");

    LocalDate from = parseDate(importedFrom, "文件夹导入开始日期");
    LocalDate to = parseDate(importedTo, "文件夹导入结束日期");
    if (from != null && to != null && from.isAfter(to)) {
      throw new ApiExceptions.BadRequest("文件夹导入开始日期不能晚于结束日期");
    }
    if (from != null) {
      where.append(" and p.created_at >= :importedFrom ");
      params.addValue("importedFrom", Timestamp.from(from.atStartOfDay(BUSINESS_ZONE).toInstant()));
    }
    if (to != null) {
      where.append(" and p.created_at < :importedTo ");
      params.addValue("importedTo",
          Timestamp.from(to.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant()));
    }

    String joins = """
        from voice_material_package p
        join student s
          on s.id = p.student_id and s.family_id = p.family_id
        """;
    Long totalValue = jdbc.queryForObject(
        "select count(*) " + joins + where, params, Long.class);
    long total = totalValue == null ? 0L : totalValue.longValue();

    params.addValue("limit", safeSize);
    params.addValue("offset", safePage * safeSize);
    String sql = """
        select
          p.id as package_id,
          p.directory_name,
        """ + folderStatusSql() + """
          as folder_status,
          p.student_id,
          s.name as student_name,
          p.subject_code,
          p.expected_minutes,
          (select count(*) from voice_material_file af
            where af.family_id = p.family_id and af.package_id = p.id
              and af.resource_type = 'AUDIO') as audio_count,
          (select count(*) from voice_material_file imf
            where imf.family_id = p.family_id and imf.package_id = p.id
              and imf.resource_type = 'IMAGE') as image_count,
          """ + usageSql + """
          as usage_count,
          (select count(*) from voice_material_task_link al
             join assignment aa on aa.id = al.assignment_id and aa.family_id = al.family_id
            where al.family_id = p.family_id and al.package_id = p.id
              and aa.status <> 'COMPLETED') as active_task_count,
          (select max(ll.created_at) from voice_material_task_link ll
            where ll.family_id = p.family_id and ll.package_id = p.id) as last_used_at,
          p.created_at as imported_at,
          p.error_message
        """ + joins + where + " order by " + folderOrder(sort)
        + " limit :limit offset :offset";
    List<VoiceMaterialDtos.VoiceFolderItemResponse> items =
        jdbc.query(sql, params, this::mapFolder);
    int totalPages = total == 0 ? 0 : (int) ((total + safeSize - 1) / safeSize);
    return new VoiceMaterialDtos.VoiceFolderPageResponse(
        items, safePage, safeSize, total, totalPages);
  }

  @Transactional(readOnly = true)
  public VoiceMaterialDtos.VoiceFolderDetailResponse folderDetail(
      UUID familyId, UUID packageId) {
    VoiceMaterialPackageEntity folder = packages.findById(packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    if (!familyId.equals(folder.familyId)) throw new ApiExceptions.NotFound("语音文件夹不存在");
    students.requireOwned(familyId, folder.studentId);

    MapSqlParameterSource params = new MapSqlParameterSource()
        .addValue("familyId", familyId)
        .addValue("packageId", packageId);
    String usageSql = "(select count(*) from voice_material_task_link ul"
        + " where ul.family_id = p.family_id and ul.package_id = p.id)";
    String itemSql = """
        select
          p.id as package_id,
          p.directory_name,
        """ + folderStatusSql() + """
          as folder_status,
          p.student_id,
          s.name as student_name,
          p.subject_code,
          p.expected_minutes,
          (select count(*) from voice_material_file af
            where af.family_id = p.family_id and af.package_id = p.id
              and af.resource_type = 'AUDIO') as audio_count,
          (select count(*) from voice_material_file imf
            where imf.family_id = p.family_id and imf.package_id = p.id
              and imf.resource_type = 'IMAGE') as image_count,
          """ + usageSql + """
          as usage_count,
          (select count(*) from voice_material_task_link al
             join assignment aa on aa.id = al.assignment_id and aa.family_id = al.family_id
            where al.family_id = p.family_id and al.package_id = p.id
              and aa.status <> 'COMPLETED') as active_task_count,
          (select max(ll.created_at) from voice_material_task_link ll
            where ll.family_id = p.family_id and ll.package_id = p.id) as last_used_at,
          p.created_at as imported_at,
          p.error_message
        from voice_material_package p
        join student s on s.id = p.student_id and s.family_id = p.family_id
        where p.family_id = :familyId and p.id = :packageId
        """;
    List<VoiceMaterialDtos.VoiceFolderItemResponse> found =
        jdbc.query(itemSql, params, this::mapFolder);
    if (found.isEmpty()) throw new ApiExceptions.NotFound("语音文件夹不存在");
    VoiceMaterialDtos.VoiceFolderItemResponse item = found.get(0);

    List<VoiceMaterialDtos.FileResponse> materialFiles =
        files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(familyId, packageId)
            .stream().map(file -> new VoiceMaterialDtos.FileResponse(
                file.id.toString(), file.assetId.toString(), file.resourceType,
                file.relativeName, file.sortOrder)).toList();

    List<VoiceMaterialDtos.VoiceFolderTaskHistoryItem> recentTasks = jdbc.query("""
        select
          l.assignment_id,
          coalesce(a.title, l.assignment_title, '') as task_name,
          coalesce(a.status, 'DELETED') as assignment_status,
          l.created_at,
          case when a.id is null then false else true end as assignment_exists
        from voice_material_task_link l
        left join assignment a
          on a.id = l.assignment_id and a.family_id = l.family_id
        where l.family_id = :familyId and l.package_id = :packageId
        order by l.created_at desc
        limit 10
        """, params, (rs, rowNum) -> new VoiceMaterialDtos.VoiceFolderTaskHistoryItem(
            rs.getString("assignment_id"),
            rs.getString("task_name"),
            rs.getString("assignment_status"),
            rs.getTimestamp("created_at").toInstant().toEpochMilli(),
            rs.getBoolean("assignment_exists")));

    return new VoiceMaterialDtos.VoiceFolderDetailResponse(
        item, materialFiles, recentTasks);
  }

  private VoiceMaterialDtos.VoiceTaskItemResponse mapTask(ResultSet rs, int rowNum)
      throws SQLException {
    Timestamp createdAt = rs.getTimestamp("task_created_at");
    return new VoiceMaterialDtos.VoiceTaskItemResponse(
        rs.getString("assignment_id"),
        rs.getString("task_name"),
        rs.getString("assignment_status"),
        rs.getString("student_id"),
        rs.getString("student_name"),
        rs.getString("subject_code"),
        rs.getInt("expected_minutes"),
        createdAt == null ? 0L : createdAt.toInstant().toEpochMilli(),
        rs.getString("package_id") == null ? "" : rs.getString("package_id"),
        rs.getString("directory_name") == null ? "本地上传" : rs.getString("directory_name"));
  }

  private VoiceMaterialDtos.VoiceFolderItemResponse mapFolder(ResultSet rs, int rowNum)
      throws SQLException {
    Timestamp lastUsed = rs.getTimestamp("last_used_at");
    Timestamp imported = rs.getTimestamp("imported_at");
    return new VoiceMaterialDtos.VoiceFolderItemResponse(
        rs.getString("package_id"),
        rs.getString("directory_name"),
        rs.getString("folder_status"),
        rs.getString("student_id"),
        rs.getString("student_name"),
        rs.getString("subject_code"),
        rs.getInt("expected_minutes"),
        rs.getInt("audio_count"),
        rs.getInt("image_count"),
        rs.getLong("usage_count"),
        rs.getLong("active_task_count"),
        lastUsed == null ? 0L : lastUsed.toInstant().toEpochMilli(),
        imported == null ? 0L : imported.toInstant().toEpochMilli(),
        rs.getString("error_message") == null ? "" : rs.getString("error_message"));
  }

  private String folderStatusSql() {
    return """
      case
        when p.status = 'INVALID' then 'INVALID'
        when p.status = 'UPLOADING' then 'PROCESSING'
        when p.status = 'ARCHIVED' then 'ARCHIVED'
        else 'READY'
      end
      """;
  }

  private String taskOrder(String sort) {
    String normalized = trim(sort).toLowerCase(Locale.ROOT);
    return switch (normalized) {
      case "createdat,asc" -> "a.created_at asc, a.id asc";
      default -> "a.created_at desc, a.id asc";
    };
  }

  private String folderOrder(String sort) {
    String normalized = trim(sort).toLowerCase(Locale.ROOT);
    return switch (normalized) {
      case "directoryname,asc" -> "p.directory_name asc, p.created_at desc, p.id asc";
      case "directoryname,desc" -> "p.directory_name desc, p.created_at desc, p.id asc";
      case "importedat,asc" -> "p.created_at asc, p.id asc";
      default -> "p.created_at desc, p.id asc";
    };
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

  private String trim(String value) {
    return value == null ? "" : value.trim();
  }
}
