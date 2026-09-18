package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import com.xiaoban.homework.student.StudentEntity;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

@Service
public class ConfigurableHomeworkOrganizerModelClient implements HomeworkOrganizerModelClient {
  private static final Logger log = LoggerFactory.getLogger(ConfigurableHomeworkOrganizerModelClient.class);

  private final AiProviderProperties properties;
  private final OpenAiCompatibleTransport transport;
  private final JsonMapper jsonMapper;

  record StructuredCandidate(String subject, String title, String instruction, String textbookRef,
      String dueText, int expectedMinutes, String sourceExcerpt, double confidence) {}
  record StructuredResult(List<StructuredCandidate> assignments) {}
  record ConversionResult(List<HomeworkOrganizerDtos.Candidate> candidates, int sourceCount,
      int unsupportedSubjectCount, int blankTitleCount, List<String> unsupportedSubjects) {}

  public ConfigurableHomeworkOrganizerModelClient(AiProviderProperties properties,
      OpenAiCompatibleTransport transport, JsonMapper jsonMapper) {
    this.properties = properties;
    this.transport = transport;
    this.jsonMapper = jsonMapper;
  }

  @Override
  public boolean available() {
    return transport.available(properties.getOrganizerModel());
  }

  @Override
  public Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel, String text) {
    Optional<String> outputText = transport.complete(
        properties.getOrganizerModel(),
        instructions(),
        buildInput(student, sourceLabel, text),
        1400,
        "homework_organization",
        structuredSchema());
    if (outputText.isEmpty()) return Optional.empty();
    try {
      StructuredResult structured = jsonMapper.readValue(stripCodeFence(outputText.get()), StructuredResult.class);
      ConversionResult converted = toCandidates(structured);
      log.info(
          "[AI] organizer parsed model={} assignments={} accepted={} unsupportedSubject={} blankTitle={} unsupportedValues={}",
          properties.getOrganizerModel(), converted.sourceCount(), converted.candidates().size(),
          converted.unsupportedSubjectCount(), converted.blankTitleCount(), converted.unsupportedSubjects());
      if (converted.sourceCount() > 0 && converted.candidates().isEmpty()) {
        log.warn(
            "[AI] organizer rejected all model assignments model={} assignments={} unsupportedSubject={} blankTitle={} unsupportedValues={}",
            properties.getOrganizerModel(), converted.sourceCount(), converted.unsupportedSubjectCount(),
            converted.blankTitleCount(), converted.unsupportedSubjects());
        return Optional.empty();
      }
      return Optional.of(converted.candidates());
    } catch (Exception error) {
      log.warn("[AI] organizer parse failed model={} outputChars={} exception={}",
          properties.getOrganizerModel(), outputText.get().length(), error.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  static String instructions() {
    return "你是深圳小学家庭作业整理助手。只做结构化整理，不解答作业。"
        + "把老师原文拆成可以逐项完成的作业，当前仅保留语文、数学、英语。"
        + "每个 assignment 的 subject 字段必须严格只填写语文、数学或英语之一，不要写语文作业、Chinese Language、Mathematics Homework等扩展标签。"
        + "同一学科一句话里有多个独立动作时要拆开；通知、缴费、带物品、家长会、值日等非作业内容忽略。"
        + "不得编造原文没有的页码、课次、截止时间或教材版本。"
        + "若原文未说明截止时间，dueText 使用今天；没有明确教材位置时 textbookRef 使用待家长确认。"
        + "请结合学生年级、任务类型和原文明确的题量、页数、遍数，为每一项给出 expectedMinutes。"
        + "expectedMinutes 只估算孩子独立完成该项任务的专注时间，不包含休息、等待、家长检查或上传时间，范围 5 到 120 分钟。"
        + "简单听读、朗读或少量口算通常可短一些；写作、大量练习或综合任务可长一些；信息不足时给出保守合理值，不为估时编造任务量。"
        + "sourceExcerpt 必须尽量直接摘取对应老师原文，confidence 为 0 到 1。"
        + "title 要简洁，instruction 保留完成任务所需信息。"
        + "最终只输出一个 JSON 对象，根字段为 assignments，不要输出 Markdown 或额外解释。";
  }

  static String buildInput(StudentEntity student, String sourceLabel, String text) {
    String grade = student.grade == null ? "" : student.grade;
    String semester = student.semester == null ? "" : student.semester;
    String textbooks = student.textbookSummary == null ? "" : student.textbookSummary;
    return "学生年级：" + grade + "\n学期：" + semester + "\n已知教材：" + textbooks
        + "\n来源：" + (sourceLabel == null ? "" : sourceLabel) + "\n老师原文：\n" + text;
  }

  static ConversionResult toCandidates(StructuredResult result) {
    List<HomeworkOrganizerDtos.Candidate> output = new ArrayList<>();
    if (result == null || result.assignments() == null) {
      return new ConversionResult(output, 0, 0, 0, List.of());
    }

    int unsupportedSubjectCount = 0;
    int blankTitleCount = 0;
    Set<String> unsupportedSubjects = new LinkedHashSet<>();
    for (StructuredCandidate item : result.assignments()) {
      if (item == null) continue;
      String subject = normalizeSubject(item.subject());
      if (subject == null) {
        unsupportedSubjectCount++;
        if (unsupportedSubjects.size() < 8) unsupportedSubjects.add(safeSubjectForLog(item.subject()));
        continue;
      }
      if (blank(item.title())) {
        blankTitleCount++;
        continue;
      }
      output.add(new HomeworkOrganizerDtos.Candidate(
          subject, item.title().trim(), value(item.instruction(), item.title()),
          value(item.textbookRef(), "待家长确认"), value(item.dueText(), "今天"),
          expectedMinutes(item.expectedMinutes()), value(item.sourceExcerpt(), item.title()),
          clamp(item.confidence())));
      if (output.size() >= 30) break;
    }
    return new ConversionResult(output, result.assignments().size(), unsupportedSubjectCount, blankTitleCount,
        List.copyOf(unsupportedSubjects));
  }

  static Map<String, Object> structuredSchema() {
    Map<String, Object> candidateProperties = new LinkedHashMap<>();
    candidateProperties.put("subject", Map.of("type", "string", "enum", List.of("语文", "数学", "英语")));
    candidateProperties.put("title", Map.of("type", "string"));
    candidateProperties.put("instruction", Map.of("type", "string"));
    candidateProperties.put("textbookRef", Map.of("type", "string"));
    candidateProperties.put("dueText", Map.of("type", "string"));
    candidateProperties.put("expectedMinutes", Map.of("type", "integer", "minimum", 5, "maximum", 120));
    candidateProperties.put("sourceExcerpt", Map.of("type", "string"));
    candidateProperties.put("confidence", Map.of("type", "number", "minimum", 0, "maximum", 1));

    Map<String, Object> candidate = new LinkedHashMap<>();
    candidate.put("type", "object");
    candidate.put("additionalProperties", false);
    candidate.put("properties", candidateProperties);
    candidate.put("required", List.of("subject", "title", "instruction", "textbookRef", "dueText",
        "expectedMinutes", "sourceExcerpt", "confidence"));

    Map<String, Object> schema = new LinkedHashMap<>();
    schema.put("type", "object");
    schema.put("additionalProperties", false);
    schema.put("properties", Map.of("assignments", Map.of("type", "array", "maxItems", 30, "items", candidate)));
    schema.put("required", List.of("assignments"));
    return schema;
  }

  private static int expectedMinutes(int value) {
    if (value <= 0) return 20;
    return Math.max(5, Math.min(120, value));
  }

  private static String stripCodeFence(String value) {
    String text = value == null ? "" : value.trim();
    if (!text.startsWith("```")) return text;
    int firstNewline = text.indexOf('\n');
    int lastFence = text.lastIndexOf("```");
    if (firstNewline >= 0 && lastFence > firstNewline) return text.substring(firstNewline + 1, lastFence).trim();
    return text;
  }

  static String normalizeSubject(String subject) {
    if (blank(subject)) return null;
    String normalized = subject.trim().replace(" ", "").replace("　", "");
    if (normalized.contains("语文")) return "语文";
    if (normalized.contains("数学")) return "数学";
    if (normalized.contains("英语")) return "英语";

    String lower = normalized.toLowerCase();
    if (lower.contains("chinese")) return "语文";
    if (lower.contains("math")) return "数学";
    if (lower.contains("english")) return "英语";
    return null;
  }

  private static String safeSubjectForLog(String subject) {
    if (subject == null) return "<null>";
    String compact = subject.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    if (compact.length() > 80) compact = compact.substring(0, 80) + "...";
    return compact;
  }

  private static boolean blank(String value) { return value == null || value.isBlank(); }
  private static String value(String value, String fallback) { return blank(value) ? fallback : value.trim(); }
  private static double clamp(double value) { return Math.max(0.0, Math.min(1.0, value)); }
}
