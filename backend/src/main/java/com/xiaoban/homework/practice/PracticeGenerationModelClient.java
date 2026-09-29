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
    Map<String, Object> outputSchema = schema(request.questionCount());
    String generationInput = input(textbookContext, grade, semester, request);

    GenerationAttempt schemaAttempt = requestAndParse(
        paperId,
        grade,
        semester,
        request,
        generationInput,
        instructions(),
        outputSchema,
        OpenAiCompatibleTransport.StructuredOutputMode.JSON_SCHEMA);
    if (schemaAttempt.paper().isPresent()) {
      logSuccess(paperId, schemaAttempt);
      return schemaAttempt.paper();
    }

    log.info(
        "[AI] practice generation schema attempt rejected model={} paperId={} shape={} outputChars={} exception={} message={} retryMode=JSON_OBJECT",
        properties.getPracticeModel(),
        paperId,
        schemaAttempt.shape(),
        schemaAttempt.outputChars(),
        schemaAttempt.exception(),
        schemaAttempt.message());

    GenerationAttempt jsonObjectAttempt = requestAndParse(
        paperId,
        grade,
        semester,
        request,
        generationInput,
        jsonObjectInstructions(),
        outputSchema,
        OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT);
    if (jsonObjectAttempt.paper().isPresent()) {
      logSuccess(paperId, jsonObjectAttempt);
      return jsonObjectAttempt.paper();
    }

    log.warn(
        "[AI] practice generation failed after structured-output negotiation model={} paperId={} firstMode=JSON_SCHEMA firstShape={} firstOutputChars={} firstException={} firstMessage={} retryMode=JSON_OBJECT retryShape={} retryOutputChars={} retryException={} retryMessage={}",
        properties.getPracticeModel(),
        paperId,
        schemaAttempt.shape(),
        schemaAttempt.outputChars(),
        schemaAttempt.exception(),
        schemaAttempt.message(),
        jsonObjectAttempt.shape(),
        jsonObjectAttempt.outputChars(),
        jsonObjectAttempt.exception(),
        jsonObjectAttempt.message());
    return Optional.empty();
  }

  private record GenerationAttempt(
      Optional<PracticeContentCatalog.Paper> paper,
      OpenAiCompatibleTransport.StructuredOutputMode mode,
      String shape,
      int outputChars,
      List<String> coercedFields,
      String exception,
      String message) {}

  private GenerationAttempt requestAndParse(
      String paperId,
      String grade,
      String semester,
      PracticeGenerationDtos.GenerateRequest request,
      String generationInput,
      String generationInstructions,
      Map<String, Object> outputSchema,
      OpenAiCompatibleTransport.StructuredOutputMode mode) {
    Optional<String> output = transport.complete(
        properties.getPracticeModel(),
        generationInstructions,
        generationInput,
        7000,
        "practice_generation",
        outputSchema,
        mode);
    if (output.isEmpty()) {
      return new GenerationAttempt(
          Optional.empty(), mode, "<empty>", 0, List.of(), "EmptyOutput", "<empty>");
    }
    return parseOutput(paperId, grade, semester, request, output.get(), mode);
  }

  private GenerationAttempt parseOutput(
      String paperId,
      String grade,
      String semester,
      PracticeGenerationDtos.GenerateRequest request,
      String output,
      OpenAiCompatibleTransport.StructuredOutputMode mode) {
    String shape = "<unparsed>";
    List<String> coercedFields = List.of();
    try {
      StructuredJsonNormalizer.Result normalized =
          StructuredJsonNormalizer.normalize(mapper, output);
      shape = normalized.shape();
      PracticeGenerationProviderAdapter.Result adapted =
          PracticeGenerationProviderAdapter.adapt(
              mapper, normalized.json(), metadataDefaults(request));
      coercedFields = adapted.coercedPaths();
      PracticeContentCatalog.Paper paper =
          toPaper(paperId, grade, semester, request, adapted.paper());
      return new GenerationAttempt(
          Optional.of(paper), mode, shape, output.length(), coercedFields, "", "");
    } catch (Exception error) {
      return new GenerationAttempt(
          Optional.empty(),
          mode,
          shape,
          output.length(),
          coercedFields,
          error.getClass().getSimpleName(),
          safeMessage(error.getMessage()));
    }
  }

  private PracticeContentCatalog.Paper toPaper(
      String paperId,
      String grade,
      String semester,
      PracticeGenerationDtos.GenerateRequest request,
      PracticeGenerationCanonicalContract.Paper modelPaper) {
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
    return new PracticeContentCatalog.Paper(
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
  }

  private void logSuccess(String paperId, GenerationAttempt attempt) {
    PracticeContentCatalog.Paper paper = attempt.paper().orElseThrow();
    log.info(
        "[AI] practice generation parsed model={} paperId={} questions={} outputMode={} shape={} coercedFields={}",
        properties.getPracticeModel(),
        paperId,
        paper.questions().size(),
        attempt.mode(),
        attempt.shape(),
        attempt.coercedFields());
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

  static String jsonObjectInstructions() {
    return instructions()
        + " 当前Provider使用JSON Object兼容模式，必须严格使用以下固定字段名，禁止改名、翻译字段名或增加替代字段："
        + " 顶层只能是questions；每题只能使用type、stem、options、answerSpec、explanation、hints、tags。"
        + " JSON示例：{\"questions\":[{\"type\":\"NUMBER\",\"stem\":\"8 + 7 = ?\",\"options\":[],"
        + "\"answerSpec\":\"15\",\"explanation\":\"8加7等于15。\","
        + "\"hints\":[\"关键词：8、加7\"],\"tags\":[\"加法\"]}]}。"
        + " 必须生成输入要求的题量，不要输出Markdown代码块或任何JSON之外的文字。";
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
