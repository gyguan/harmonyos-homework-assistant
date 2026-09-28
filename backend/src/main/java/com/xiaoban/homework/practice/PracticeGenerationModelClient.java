package com.xiaoban.homework.practice;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import com.xiaoban.homework.ai.StructuredJsonNormalizer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

@Service
public class PracticeGenerationModelClient {
  private static final Logger log = LoggerFactory.getLogger(PracticeGenerationModelClient.class);

  private final AiProviderProperties properties;
  private final OpenAiCompatibleTransport transport;
  private final JsonMapper mapper;

  public PracticeGenerationModelClient(AiProviderProperties properties,
      OpenAiCompatibleTransport transport, JsonMapper mapper) {
    this.properties = properties;
    this.transport = transport;
    this.mapper = mapper;
  }

  public String model() {
    return properties.getPracticeModel();
  }

  public boolean available() {
    return transport.available(properties.getPracticeModel());
  }

  public Optional<PracticeContentCatalog.Paper> generate(
      String textbookContext,
      String paperId,
      String grade,
      String semester,
      PracticeGenerationDtos.GenerateRequest request) {
    Optional<String> output = transport.complete(
        properties.getPracticeModel(),
        instructions(),
        input(textbookContext, grade, semester, request),
        7000,
        "practice_generation",
        schema(request.questionCount()));
    if (output.isEmpty()) return Optional.empty();

    String shape = "<unparsed>";
    List<String> coercedFields = List.of();
    try {
      StructuredJsonNormalizer.Result normalized =
          StructuredJsonNormalizer.normalize(mapper, output.get());
      shape = normalized.shape();
      PracticeGenerationProviderAdapter.Result adapted =
          PracticeGenerationProviderAdapter.adapt(
              mapper, normalized.json(), metadataDefaults(request));
      coercedFields = adapted.coercedPaths();
      PracticeGenerationCanonicalContract.Paper modelPaper = adapted.paper();

      ArrayList<PracticeContentCatalog.Question> questions = new ArrayList<>();
      for (int i = 0; i < modelPaper.questions().size(); i++) {
        PracticeGenerationCanonicalContract.Question source = modelPaper.questions().get(i);
        ArrayList<PracticeContentCatalog.Option> options = new ArrayList<>();
        for (PracticeGenerationCanonicalContract.Option option : source.options()) {
          options.add(new PracticeContentCatalog.Option(option.key(), option.label()));
        }
        String questionId = paperId + "-Q" + String.format("%02d", i + 1);
        questions.add(new PracticeContentCatalog.Question(
            questionId,
            i + 1,
            source.type(),
            source.stem(),
            options,
            source.answerSpec(),
            source.explanation(),
            source.hints(),
            source.tags()));
      }
      PracticeContentCatalog.Paper paper = new PracticeContentCatalog.Paper(
          paperId,
          1,
          grade,
          request.subject().trim().toUpperCase(),
          semester,
          request.track().trim().toUpperCase(),
          modelPaper.title(),
          modelPaper.description(),
          request.difficulty().trim().toUpperCase(),
          questions.size(),
          Math.max(1, Math.min(120, modelPaper.estimatedMinutes())),
          modelPaper.tags(),
          "AI_GENERATED",
          "PUBLISHED",
          questions);
      log.info(
          "[AI] practice generation parsed model={} paperId={} questions={} shape={} coercedFields={}",
          properties.getPracticeModel(), paperId, questions.size(), shape, coercedFields);
      return Optional.of(paper);
    } catch (Exception error) {
      log.warn(
          "[AI] practice generation parse failed model={} paperId={} outputChars={} shape={} coercedFields={} exception={} message={}",
          properties.getPracticeModel(), paperId, output.get().length(), shape, coercedFields,
          error.getClass().getSimpleName(), safeMessage(error.getMessage()));
      return Optional.empty();
    }
  }

  static String instructions() {
    return "你是小学练习题设计助手。只生成适合指定学生年级和学期的纯文本练习题。"
        + "必须严格遵守输入中的科目、题库类型、难度、题量和家长训练要求。"
        + "教材同步题只能基于输入中明确提供的教材信息和训练要求，不得猜测教材版本、单元或课文。"
        + "课外拓展可以生活化和有趣，但不得用高年级知识包装成拓展。"
        + "题目必须自包含，禁止依赖图片、看图、上图、画面或外部材料。"
        + "第一版只允许 SINGLE_CHOICE、FILL_BLANK、NUMBER。"
        + "单选题必须提供3到4个互不重复选项，answerSpec只能是一个真实存在的选项key。"
        + "填空题 answerSpec 用竖线分隔可接受答案；NUMBER 的 answerSpec 必须是纯数字。"
        + "英语题干必须包含中文操作说明。"
        + "每题 hints 必须只有1条，并以“关键词：”开头，提示来自本题关键条件但不能泄露答案。"
        + "explanation 要解释为什么，语言适合孩子和家长阅读。"
        + "同卷题目要覆盖不同角度，禁止只替换数字、姓名或物品形成机械重复。"
        + "正确答案位置要自然分散，不能长期固定在第一个选项。"
        + "生成前自行复核每题答案、选项唯一性、数学计算和年级适配。"
        + "顶层只输出 questions 数组，不需要生成 title、description、estimatedMinutes 或 tags。"
        + "最终只输出符合JSON Schema的对象，不输出Markdown或额外说明。";
  }

  static String input(String textbookContext, String grade, String semester,
      PracticeGenerationDtos.GenerateRequest request) {
    String textbooks = textbookContext == null ? "" : textbookContext.trim();
    return "学生年级：" + grade
        + "\n学期：" + semester
        + "\n科目：" + request.subject()
        + "\n题库类型：" + request.track()
        + "\n难度：" + request.difficulty()
        + "\n题量：" + request.questionCount()
        + "\n已知教材：" + textbooks
        + "\n家长训练要求：" + request.requirement().trim();
  }

  static Map<String, Object> schema(int questionCount) {
    Map<String, Object> optionProps = new LinkedHashMap<>();
    optionProps.put("key", Map.of("type", "string"));
    optionProps.put("label", Map.of("type", "string"));
    Map<String, Object> option = object(optionProps, List.of("key", "label"));

    Map<String, Object> questionProps = new LinkedHashMap<>();
    questionProps.put("type", Map.of(
        "type", "string",
        "enum", List.of("SINGLE_CHOICE", "FILL_BLANK", "NUMBER")));
    questionProps.put("stem", Map.of("type", "string"));
    questionProps.put("options", Map.of(
        "type", "array",
        "minItems", 0,
        "maxItems", 4,
        "items", option));
    questionProps.put("answerSpec", Map.of("type", "string"));
    questionProps.put("explanation", Map.of("type", "string"));
    questionProps.put("hints", Map.of(
        "type", "array",
        "minItems", 1,
        "maxItems", 1,
        "items", Map.of("type", "string")));
    questionProps.put("tags", Map.of(
        "type", "array",
        "minItems", 1,
        "maxItems", 6,
        "items", Map.of("type", "string")));
    Map<String, Object> question = object(
        questionProps,
        List.of("type", "stem", "options", "answerSpec", "explanation", "hints", "tags"));

    Map<String, Object> generationProps = new LinkedHashMap<>();
    generationProps.put("questions", Map.of(
        "type", "array",
        "minItems", questionCount,
        "maxItems", questionCount,
        "items", question));
    return object(generationProps, List.of("questions"));
  }

  static PracticeGenerationProviderAdapter.MetadataDefaults metadataDefaults(
      PracticeGenerationDtos.GenerateRequest request) {
    String subject = normalizeCode(request.subject());
    String track = normalizeCode(request.track());
    String subjectLabel = switch (subject) {
      case "CHINESE" -> "语文";
      case "MATH" -> "数学";
      case "ENGLISH" -> "英语";
      default -> "练习";
    };
    String trackLabel = switch (track) {
      case "TEXTBOOK_SYNC" -> "教材同步";
      case "EXTRACURRICULAR" -> "课外拓展";
      default -> "专项";
    };
    String requirement = compactText(request.requirement());
    String title = requirement.length() <= 32
        ? requirement
        : subjectLabel + trackLabel + "练习";
    if (title.isBlank()) title = subjectLabel + trackLabel + "练习";
    String description = "AI根据家长训练要求生成的" + subjectLabel + trackLabel + "练习";
    int estimatedMinutes = Math.max(5, Math.min(120, request.questionCount() * 2));
    return new PracticeGenerationProviderAdapter.MetadataDefaults(
        title,
        description,
        estimatedMinutes,
        List.of(subjectLabel, trackLabel));
  }

  private static String normalizeCode(String value) {
    return value == null ? "" : value.trim().toUpperCase();
  }

  private static String compactText(String value) {
    return value == null ? "" : value.trim().replaceAll("\\s+", " ");
  }

  private static String safeMessage(String value) {
    if (value == null || value.isBlank()) return "<empty>";
    String compact = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    return compact.length() <= 300 ? compact : compact.substring(0, 300);
  }

  private static Map<String, Object> object(Map<String, Object> properties, List<String> required) {
    Map<String, Object> value = new LinkedHashMap<>();
    value.put("type", "object");
    value.put("additionalProperties", false);
    value.put("properties", properties);
    value.put("required", required);
    return value;
  }
}
