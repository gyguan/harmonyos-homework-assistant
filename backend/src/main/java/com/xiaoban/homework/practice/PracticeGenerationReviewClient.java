package com.xiaoban.homework.practice;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

@Service
public class PracticeGenerationReviewClient {
  private static final Logger log = LoggerFactory.getLogger(PracticeGenerationReviewClient.class);

  public record ReviewIssue(String questionId, String reason) {}
  public record ReviewResult(boolean passed, List<ReviewIssue> issues) {}

  private final AiProviderProperties properties;
  private final OpenAiCompatibleTransport transport;
  private final JsonMapper mapper;

  public PracticeGenerationReviewClient(
      AiProviderProperties properties,
      OpenAiCompatibleTransport transport,
      JsonMapper mapper) {
    this.properties = properties;
    this.transport = transport;
    this.mapper = mapper;
  }

  public Optional<ReviewResult> review(PracticeContentCatalog.Paper paper) {
    try {
      String input = mapper.writeValueAsString(paper);
      Optional<String> output = transport.complete(
          properties.getPracticeModel(),
          instructions(),
          input,
          3000,
          "practice_generation_review",
          schema());
      if (output.isEmpty()) return Optional.empty();

      ReviewResult result = mapper.readValue(output.get().trim(), ReviewResult.class);
      if (result == null || result.issues() == null) return Optional.empty();
      if (result.passed() && !result.issues().isEmpty()) {
        log.warn("[AI] practice review inconsistent paperId={} passed=true issues={}",
            paper.id(), result.issues().size());
        return Optional.of(new ReviewResult(false, result.issues()));
      }
      log.info("[AI] practice review completed paperId={} passed={} issues={}",
          paper.id(), result.passed(), result.issues().size());
      return Optional.of(result);
    } catch (Exception error) {
      log.warn("[AI] practice review parse failed paperId={} exception={}",
          paper.id(), error.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  static String instructions() {
    return "你是小学练习题答案复核员。输入是一套已经生成的练习题JSON。"
        + "不要改写题目，只检查：题干是否有唯一合理答案、answerSpec是否正确、"
        + "选择题答案是否指向正确选项、解析是否与正确答案一致、题目是否存在明显歧义、"
        + "知识难度是否明显超出给定年级和学期。"
        + "数学题必须独立重新计算，不能相信输入中的answerSpec或explanation。"
        + "语文和英语题必须独立判断答案是否成立。"
        + "只要发现任何答案错误、歧义或解析矛盾，passed必须为false，并在issues中给出questionId和简短原因。"
        + "没有问题时passed为true且issues为空。最终只输出符合JSON Schema的对象。";
  }

  static Map<String, Object> schema() {
    Map<String, Object> issueProps = new LinkedHashMap<>();
    issueProps.put("questionId", Map.of("type", "string"));
    issueProps.put("reason", Map.of("type", "string"));
    Map<String, Object> issue = object(issueProps, List.of("questionId", "reason"));

    Map<String, Object> rootProps = new LinkedHashMap<>();
    rootProps.put("passed", Map.of("type", "boolean"));
    rootProps.put("issues", Map.of(
        "type", "array",
        "maxItems", 20,
        "items", issue));
    return object(rootProps, List.of("passed", "issues"));
  }

  private static Map<String, Object> object(
      Map<String, Object> properties, List<String> required) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("type", "object");
    result.put("additionalProperties", false);
    result.put("properties", properties);
    result.put("required", required);
    return result;
  }
}
