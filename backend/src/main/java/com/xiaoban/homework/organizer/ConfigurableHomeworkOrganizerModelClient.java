package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.ImageAiRequestException;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import java.time.LocalDate;
import java.time.ZoneId;
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
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

@Service
public class ConfigurableHomeworkOrganizerModelClient implements HomeworkOrganizerModelClient {
  private static final Logger log = LoggerFactory.getLogger(ConfigurableHomeworkOrganizerModelClient.class);
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private final AiProviderProperties properties;
  private final OpenAiCompatibleTransport transport;
  private final JsonMapper jsonMapper;

  record StructuredCandidate(String subject, String title, String instruction, String textbookRef,
      String taskDate, int expectedMinutes, String sourceExcerpt, double confidence) {}
  record StructuredResult(List<StructuredCandidate> assignments) {}
  record ImageStructuredCandidate(String subject, String title, String instruction,
      String textbookRef, String sourceExcerpt) {}
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
  public boolean imageAvailable() { return transport.available(properties.getImageOrganizerModel()); }

  @Override
  public Optional<HomeworkOrganizerDtos.ImageResponse> organizeImage(StudentEntity student,
      String sourceLabel, String imageDataUrl, String text) {
    Optional<String> output;
    try {
      output = transport.completeWithImage(
          properties.getImageOrganizerModel(),
          imageInstructions(),
          imageInput(student, sourceLabel, text),
          imageDataUrl, 2200, "homework_image_organization", imageSchema());
    } catch (ImageAiRequestException error) {
      throw new ApiExceptions.ServiceUnavailable(error.getMessage());
    }
    if (output.isEmpty()) return Optional.empty();
    try {
      return parseImageOutput(output.get());
    } catch (Exception error) {
      log.warn("homework_import image_parse_failed model={} outputChars={} exception={}",
          properties.getImageOrganizerModel(), output.get().length(), error.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  static String imageInput(StudentEntity student, String sourceLabel, String text) {
    return buildInput(student, sourceLabel,
        "请读取附图并整理全部作业。只输出结构化作业，不要额外转写整张图片。")
        + "\n补充文字（可能为空）：\n" + (text == null ? "" : text.trim());
  }

  Optional<HomeworkOrganizerDtos.ImageResponse> parseImageOutput(String output) {
    JsonNode root = jsonMapper.readTree(stripCodeFence(output));
    List<JsonNode> nodes = imageAssignmentNodes(root);
    if (nodes.isEmpty() || nodes.size() > 30) return Optional.empty();

    List<ImageStructuredCandidate> parsed = new ArrayList<>();
    for (JsonNode node : nodes) {
      ImageStructuredCandidate candidate = imageCandidate(node);
      if (candidate != null) parsed.add(candidate);
    }
    List<HomeworkOrganizerDtos.Candidate> converted = toImageCandidates(parsed);
    if (converted.isEmpty()) return Optional.empty();

    int dropped = nodes.size() - converted.size();
    if (dropped > 0) {
      log.warn("homework_import image_parse_normalized model={} assignments={} accepted={} dropped={}",
          properties.getImageOrganizerModel(), nodes.size(), converted.size(), dropped);
    }
    return Optional.of(new HomeworkOrganizerDtos.ImageResponse(
        converted, "AI_IMAGE", recognizedText(converted)));
  }

  static String imageInstructions() {
    return "你是深圳小学作业图片整理器，只读取并结构化作业任务，不解答作业。"
        + "图片可能包含多个科目，逐项识别，不把整张图片归为单一科目。"
        + "每项只输出 subject、title、instruction、textbookRef、sourceExcerpt 五个字段。"
        + "subject 必须严格填写语文、数学、英语、阅读、朗读、体育、实践、兴趣、其他之一。"
        + "title 要简洁；instruction 保留完成任务所需信息；没有明确教材位置时 textbookRef 填待家长确认。"
        + "sourceExcerpt 只摘取对应作业的简短原文，必须保留原文出现的今天、明天、具体日期或截止时间。"
        + "通知、缴费、带物品、家长会、值日、群聊闲聊等非作业内容忽略。"
        + "明显属于同一任务的重复表述直接合并；无法辨认的内容不得猜测。"
        + "不要输出 taskDate、expectedMinutes、confidence，不要全文转写图片，不要输出解释或 Markdown。";
  }

  static Map<String, Object> imageSchema() {
    Map<String, Object> candidateProperties = new LinkedHashMap<>();
    candidateProperties.put("subject", Map.of("type", "string", "enum",
        List.of("语文", "数学", "英语", "阅读", "朗读", "体育", "实践", "兴趣", "其他")));
    candidateProperties.put("title", Map.of("type", "string", "maxLength", 80));
    candidateProperties.put("instruction", Map.of("type", "string", "maxLength", 600));
    candidateProperties.put("textbookRef", Map.of("type", "string", "maxLength", 120));
    candidateProperties.put("sourceExcerpt", Map.of("type", "string", "maxLength", 300));

    Map<String, Object> candidate = new LinkedHashMap<>();
    candidate.put("type", "object");
    candidate.put("additionalProperties", false);
    candidate.put("properties", candidateProperties);
    candidate.put("required", List.of(
        "subject", "title", "instruction", "textbookRef", "sourceExcerpt"));

    Map<String, Object> schema = new LinkedHashMap<>();
    schema.put("type", "object");
    schema.put("additionalProperties", false);
    schema.put("properties", Map.of(
        "assignments", Map.of("type", "array", "maxItems", 30, "items", candidate)));
    schema.put("required", List.of("assignments"));
    return schema;
  }

  static List<HomeworkOrganizerDtos.Candidate> toImageCandidates(List<ImageStructuredCandidate> items) {
    List<HomeworkOrganizerDtos.Candidate> output = new ArrayList<>();
    if (items == null) return output;
    for (ImageStructuredCandidate item : items) {
      if (item == null) continue;
      String subject = normalizeSubject(item.subject());
      if (subject == null || blank(item.title())) continue;
      String title = item.title().trim();
      String instruction = value(item.instruction(), title);
      String excerpt = value(item.sourceExcerpt(), title);
      LocalDate parsedDate = candidateTaskDate(excerpt);
      if (parsedDate == null) parsedDate = candidateTaskDate(instruction);
      String taskDate = (parsedDate == null ? LocalDate.now(BUSINESS_ZONE) : parsedDate).toString();
      output.add(new HomeworkOrganizerDtos.Candidate(
          subject, title, instruction, value(item.textbookRef(), "待家长确认"), taskDate,
          imageExpectedMinutes(subject, title, instruction, excerpt), excerpt, 0.85,
          "", "", "", 0.0, ""));
      if (output.size() >= 30) break;
    }
    return output;
  }

  static List<JsonNode> imageAssignmentNodes(JsonNode root) {
    List<JsonNode> result = new ArrayList<>();
    if (root == null || root.isNull()) return result;

    JsonNode container = root;
    if (root.isObject()) {
      JsonNode selected = firstNode(root, "assignments", "tasks", "items", "data");
      if (selected != null) container = selected;
      else if (!looksLikeImageCandidate(root)) return result;
    }

    if (container.isObject()) {
      JsonNode nested = firstNode(container, "assignments", "tasks", "items", "list", "data");
      if (nested != null) container = nested;
    }

    if (container.isArray()) {
      for (JsonNode item : container) {
        if (item != null && item.isObject()) result.add(item);
        if (result.size() > 30) break;
      }
    } else if (container.isObject() && looksLikeImageCandidate(container)) {
      result.add(container);
    }
    return result;
  }

  static ImageStructuredCandidate imageCandidate(JsonNode node) {
    if (node == null || !node.isObject()) return null;
    String subject = imageFieldText(node, 80, "subject", "subjectName", "course", "category");
    String title = imageFieldText(node, 80, "title", "task", "taskTitle", "name");
    String instruction = imageFieldText(
        node, 600, "instruction", "content", "description", "requirement", "requirements");
    String textbookRef = imageFieldText(
        node, 120, "textbookRef", "textbook", "book", "page", "reference");
    String sourceExcerpt = imageFieldText(
        node, 300, "sourceExcerpt", "excerpt", "source", "originalText", "rawText");

    if (blank(subject) || blank(title)) return null;
    return new ImageStructuredCandidate(
        subject, title, value(instruction, title),
        value(textbookRef, "待家长确认"), value(sourceExcerpt, title));
  }

  static String imageFieldText(JsonNode object, int maxLength, String... names) {
    if (object == null || !object.isObject()) return "";
    for (String name : names) {
      JsonNode value = object.get(name);
      String normalized = jsonText(value, maxLength);
      if (!blank(normalized)) return normalized;
    }
    return "";
  }

  static String jsonText(JsonNode node, int maxLength) {
    if (node == null || node.isNull()) return "";
    String text;
    if (node.isTextual() || node.isNumber() || node.isBoolean()) {
      text = node.asText();
    } else if (node.isArray()) {
      LinkedHashSet<String> values = new LinkedHashSet<>();
      for (JsonNode item : node) {
        String value = jsonText(item, maxLength);
        if (!blank(value)) values.add(value);
        if (values.size() >= 8) break;
      }
      text = String.join("；", values);
    } else if (node.isObject()) {
      LinkedHashSet<String> values = new LinkedHashSet<>();
      for (String key : List.of(
          "text", "value", "name", "label", "content", "description",
          "book", "page", "excerpt", "title")) {
        String value = jsonText(node.get(key), maxLength);
        if (!blank(value)) values.add(value);
      }
      text = String.join("；", values);
    } else {
      text = "";
    }
    String compact = compact(text, maxLength);
    return compact.length() <= maxLength ? compact : compact.substring(0, maxLength);
  }

  static JsonNode firstNode(JsonNode object, String... names) {
    if (object == null || !object.isObject()) return null;
    for (String name : names) {
      JsonNode value = object.get(name);
      if (value != null && !value.isNull()) return value;
    }
    return null;
  }

  static boolean looksLikeImageCandidate(JsonNode node) {
    if (node == null || !node.isObject()) return false;
    return firstNode(node, "subject", "subjectName", "course", "category") != null
        && firstNode(node, "title", "task", "taskTitle", "name") != null;
  }

  static int imageExpectedMinutes(String subject, String title, String instruction, String excerpt) {
    String text = (value(subject, "") + " " + value(title, "") + " "
        + value(instruction, "") + " " + value(excerpt, "")).toLowerCase();

    java.util.regex.Matcher quantity =
        java.util.regex.Pattern.compile("(\\d{1,3})\\s*(?:题|道)").matcher(text);
    if (quantity.find()) {
      int count = Integer.parseInt(quantity.group(1));
      if (count <= 10) return 10;
      if (count <= 30) return 15;
      if (count <= 60) return 25;
      return 35;
    }
    if (text.contains("作文") || text.contains("写作") || text.contains("习作")
        || text.contains("日记")) return 40;
    if (text.contains("实践") || text.contains("劳动") || text.contains("手工")) return 30;
    if (text.contains("阅读") || text.contains("读书")) return 20;
    if (text.contains("背诵") || text.contains("背会")) return 15;
    if (text.contains("朗读") || text.contains("朗诵") || text.contains("听读")) return 10;
    if (text.contains("体育") || text.contains("运动") || text.contains("跳绳")
        || text.contains("跑步")) return 20;
    return 20;
  }

  static String recognizedText(List<HomeworkOrganizerDtos.Candidate> candidates) {
    LinkedHashSet<String> excerpts = new LinkedHashSet<>();
    for (HomeworkOrganizerDtos.Candidate candidate : candidates) {
      if (candidate == null || blank(candidate.sourceExcerpt())) continue;
      excerpts.add(candidate.sourceExcerpt().trim());
    }
    String joined = String.join("\n", excerpts);
    return joined.length() <= 3000 ? joined : joined.substring(0, 3000);
  }

  @Override
  public Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel, String text) {
    return organizeRaw(student, sourceLabel, text);
  }

  private Optional<List<HomeworkOrganizerDtos.Candidate>> organizeRaw(
      StudentEntity student, String sourceLabel, String text) {
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
    return "你是深圳小学家庭任务整理助手。只做结构化整理，不解答作业。"
        + "输入既可能是老师作业通知，也可能是家长直接布置的阅读、朗读、体育、实践或兴趣任务。"
        + "把输入拆成可以逐项完成的任务。subject 字段必须严格填写语文、数学、英语、阅读、朗读、体育、实践、兴趣、其他之一。"
        + "学校学科任务优先使用语文、数学、英语；非学科家庭任务按内容选择阅读、朗读、体育、实践、兴趣或其他。"
        + "同一类任务一句话里有多个独立动作时要拆开；通知、缴费、带物品、家长会、值日等非任务内容忽略。"
        + "不得编造原文没有的页码、课次、任务日期或教材版本。"
        + "taskDate 必须输出 YYYY-MM-DD；若原文未说明任务日期，使用今天对应的日期；没有明确教材位置时 textbookRef 使用待家长确认。"
        + "请结合学生年级、任务类型和原文明确的题量、页数、遍数，为每一项给出 expectedMinutes。"
        + "expectedMinutes 只估算孩子独立完成该项任务的专注时间，不包含休息、等待、家长检查或上传时间，范围 5 到 120 分钟。"
        + "简单听读、朗读或少量口算通常可短一些；写作、大量练习或综合任务可长一些；信息不足时给出保守合理值，不为估时编造任务量。"
        + "sourceExcerpt 必须尽量直接摘取对应老师原文，confidence 为 0 到 1。"
        + "title 要简洁，instruction 保留完成任务所需信息。"
        + "明显属于同一任务的重复表述直接合并，不做重复任务对比或额外标记。"
        + "最终只输出一个 JSON 对象，根字段为 assignments，不要输出 Markdown 或额外解释。";
  }

  static String buildInput(StudentEntity student, String sourceLabel, String text) {
    String grade = student.grade == null ? "" : student.grade;
    String semester = student.semester == null ? "" : student.semester;
    String textbooks = student.textbookSummary == null ? "" : student.textbookSummary;
    return "当前日期：" + LocalDate.now(BUSINESS_ZONE) + "\n学生年级：" + grade + "\n学期：" + semester + "\n已知教材：" + textbooks
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
      LocalDate parsedTaskDate = candidateTaskDate(item.taskDate());
      String taskDate = parsedTaskDate == null ? LocalDate.now(BUSINESS_ZONE).toString() : parsedTaskDate.toString();
      output.add(new HomeworkOrganizerDtos.Candidate(
          subject, item.title().trim(), value(item.instruction(), item.title()),
          value(item.textbookRef(), "待家长确认"), taskDate,
          expectedMinutes(item.expectedMinutes()), value(item.sourceExcerpt(), item.title()),
          clamp(item.confidence()), "", "", "", 0.0, ""));
      if (output.size() >= 30) break;
    }
    return new ConversionResult(output, result.assignments().size(), unsupportedSubjectCount, blankTitleCount,
        List.copyOf(unsupportedSubjects));
  }

  static Map<String, Object> structuredSchema() {
    Map<String, Object> candidateProperties = new LinkedHashMap<>();
    candidateProperties.put("subject", Map.of("type", "string", "enum",
        List.of("语文", "数学", "英语", "阅读", "朗读", "体育", "实践", "兴趣", "其他")));
    candidateProperties.put("title", Map.of("type", "string", "maxLength", 80));
    candidateProperties.put("instruction", Map.of("type", "string", "maxLength", 800));
    candidateProperties.put("textbookRef", Map.of("type", "string", "maxLength", 120));
    candidateProperties.put("taskDate", Map.of("type", "string", "maxLength", 20));
    candidateProperties.put("expectedMinutes", Map.of("type", "integer", "minimum", 5, "maximum", 120));
    candidateProperties.put("sourceExcerpt", Map.of("type", "string", "maxLength", 400));
    candidateProperties.put("confidence", Map.of("type", "number", "minimum", 0, "maximum", 1));

    Map<String, Object> candidate = new LinkedHashMap<>();
    candidate.put("type", "object");
    candidate.put("additionalProperties", false);
    candidate.put("properties", candidateProperties);
    candidate.put("required", List.of("subject", "title", "instruction", "textbookRef", "taskDate",
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
    if (normalized.contains("阅读")) return "阅读";
    if (normalized.contains("朗读") || normalized.contains("朗诵")) return "朗读";
    if (normalized.contains("体育") || normalized.contains("运动")) return "体育";
    if (normalized.contains("实践") || normalized.contains("劳动")) return "实践";
    if (normalized.contains("兴趣")) return "兴趣";
    if (normalized.contains("其他")) return "其他";

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

  static LocalDate candidateTaskDate(String value) {
    if (blank(value)) return null;
    String text = value.trim();
    LocalDate today = LocalDate.now(BUSINESS_ZONE);
    if (text.contains("后天")) return today.plusDays(2);
    if (text.contains("明天") || text.contains("明日")) return today.plusDays(1);
    if (text.contains("今天") || text.contains("今日") || text.contains("今晚")) return today;

    java.util.regex.Matcher fullChinese =
        java.util.regex.Pattern.compile("(\\d{4})年(\\d{1,2})月(\\d{1,2})[日号]?").matcher(text);
    if (fullChinese.find()) {
      return validDate(
          Integer.parseInt(fullChinese.group(1)),
          Integer.parseInt(fullChinese.group(2)),
          Integer.parseInt(fullChinese.group(3)));
    }

    java.util.regex.Matcher fullNumeric =
        java.util.regex.Pattern.compile("(\\d{4})[-/.](\\d{1,2})[-/.](\\d{1,2})").matcher(text);
    if (fullNumeric.find()) {
      return validDate(
          Integer.parseInt(fullNumeric.group(1)),
          Integer.parseInt(fullNumeric.group(2)),
          Integer.parseInt(fullNumeric.group(3)));
    }

    java.util.regex.Matcher monthDay =
        java.util.regex.Pattern.compile("(\\d{1,2})月(\\d{1,2})[日号]?").matcher(text);
    if (monthDay.find()) {
      return validDate(today.getYear(),
          Integer.parseInt(monthDay.group(1)), Integer.parseInt(monthDay.group(2)));
    }

    java.util.regex.Matcher numericMonthDay =
        java.util.regex.Pattern.compile("(^|[^\\d])(\\d{1,2})[-/.](\\d{1,2})($|[^\\d])").matcher(text);
    if (numericMonthDay.find()) {
      return validDate(today.getYear(),
          Integer.parseInt(numericMonthDay.group(2)), Integer.parseInt(numericMonthDay.group(3)));
    }

    java.util.regex.Matcher weekday =
        java.util.regex.Pattern.compile("(?:周|星期)([一二三四五六日天])").matcher(text);
    if (weekday.find()) {
      int target = switch (weekday.group(1)) {
        case "一" -> 1;
        case "二" -> 2;
        case "三" -> 3;
        case "四" -> 4;
        case "五" -> 5;
        case "六" -> 6;
        default -> 7;
      };
      int current = today.getDayOfWeek().getValue();
      int delta = (target - current + 7) % 7;
      return today.plusDays(delta);
    }
    return null;
  }

  private static LocalDate validDate(int year, int month, int day) {
    try {
      return LocalDate.of(year, month, day);
    } catch (java.time.DateTimeException error) {
      return null;
    }
  }

  private static String compact(String value, int maxLength) {
    if (blank(value)) return "";
    String normalized = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    return normalized.length() <= maxLength ? normalized : normalized.substring(0, maxLength);
  }

  private static boolean blank(String value) { return value == null || value.isBlank(); }
  private static String value(String value, String fallback) { return blank(value) ? fallback : value.trim(); }
  private static double clamp(double value) { return Math.max(0.0, Math.min(1.0, value)); }
}
