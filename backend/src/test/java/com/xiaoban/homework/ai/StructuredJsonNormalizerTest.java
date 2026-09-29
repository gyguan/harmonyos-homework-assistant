package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.Map;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class StructuredJsonNormalizerTest {
  private final JsonMapper mapper = JsonMapper.builder().build();

  @Test
  void normalizesMarkdownFence() throws Exception {
    StructuredJsonNormalizer.Result result = StructuredJsonNormalizer.normalize(
        mapper, "```json\n{\"title\":\"数学练习\"}\n```");

    assertEquals("fenced>object", result.shape());
    assertEquals("数学练习", mapper.readValue(result.json(), Map.class).get("title"));
  }

  @Test
  void normalizesQuotedJson() throws Exception {
    String quoted = mapper.writeValueAsString("{\"title\":\"数学练习\"}");
    StructuredJsonNormalizer.Result result = StructuredJsonNormalizer.normalize(mapper, quoted);

    assertEquals("quoted>object", result.shape());
    assertEquals("数学练习", mapper.readValue(result.json(), Map.class).get("title"));
  }

  @Test
  void normalizesSingletonArray() throws Exception {
    StructuredJsonNormalizer.Result result = StructuredJsonNormalizer.normalize(
        mapper, "[{\"title\":\"数学练习\"}]");

    assertEquals("singleton-array>object", result.shape());
    assertEquals("数学练习", mapper.readValue(result.json(), Map.class).get("title"));
  }

  @Test
  void unwrapsCommonPaperWrapper() throws Exception {
    StructuredJsonNormalizer.Result result = StructuredJsonNormalizer.normalize(
        mapper, "{\"paper\":{\"title\":\"数学练习\"}}");

    assertEquals("wrapper:paper>object", result.shape());
    assertEquals("数学练习", mapper.readValue(result.json(), Map.class).get("title"));
  }

  @Test
  void extractsJsonFromLeadingExplanation() throws Exception {
    StructuredJsonNormalizer.Result result = StructuredJsonNormalizer.normalize(
        mapper, "以下为生成结果：\n{\"title\":\"数学练习\"}\n请查收");

    assertEquals("embedded>object", result.shape());
    assertEquals("数学练习", mapper.readValue(result.json(), Map.class).get("title"));
  }
}
