package com.xiaoban.homework.organizer;

import com.xiaoban.homework.student.StudentEntity;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

@Service
public class OpenAiHomeworkOrganizerModelClient implements HomeworkOrganizerModelClient {
  private static final Logger log = LoggerFactory.getLogger(OpenAiHomeworkOrganizerModelClient.class);
  private final String apiKey;
  private final String model;
  private final RestClient client;
  private final JsonMapper jsonMapper;

  record OpenAiContent(String type, String text) {}
  record OpenAiOutput(List<OpenAiContent> content) {}
  record OpenAiResponse(List<OpenAiOutput> output) {}
  record StructuredCandidate(String subject, String title, String instruction, String textbookRef,
      String dueText, String sourceExcerpt, double confidence) {}
  record StructuredResult(List<StructuredCandidate> assignments) {}

  public OpenAiHomeworkOrganizerModelClient(
      @Value("${app.organizer.openai.api-key:}") String apiKey,
      @Value("${app.organizer.openai.model:gpt-5.6-luna}") String model,
      @Value("${app.organizer.openai.base-url:https://api.openai.com}") String baseUrl,
      JsonMapper jsonMapper) {
    this.apiKey = apiKey == null ? "" : apiKey.trim();
    this.model = model;
    this.client = RestClient.builder().baseUrl(baseUrl)
        .defaultHeader(HttpHeaders.CONTENT_TYPE, "application/json").build();
    this.jsonMapper = jsonMapper;
  }

  @Override
  public boolean available() { return !apiKey.isBlank(); }

  @Override
  public Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel, String text) {
    if (!available()) return Optional.empty();
    try {
      Map<String, Object> body = new LinkedHashMap<>();
      body.put("model", model);
      body.put("store", false);
      body.put("instructions", instructions());
      body.put("input", buildInput(student, sourceLabel, text));
      body.put("max_output_tokens", 1400);
      body.put("text", Map.of("format", structuredFormat()));

      OpenAiResponse response = client.post().uri("/v1/responses")
          .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
          .body(body).retrieve().body(OpenAiResponse.class);
      Optional<String> outputText = extractText(response);
      if (outputText.isEmpty()) return Optional.empty();
      StructuredResult structured = jsonMapper.readValue(outputText.get(), StructuredResult.class);
      return Optional.of(toCandidates(structured));
    } catch (Exception error) {
      log.warn("Homework organizer model request failed: {}", error.getMessage());
      return Optional.empty();
    }
  }

  static String instructions() {
    return "你是深圳小学家庭作业整理助手。只做结构化整理，不解答作业。"
        + "把老师原文拆成可以逐项完成的作业，当前仅保留语文、数学、英语。"
        + "同一学科一句话里有多个独立动作时要拆开；通知、缴费、带物品、家长会、值日等非作业内容忽略。"
        + "不得编造原文没有的页码、课次、截止时间或教材版本。"
        + "若原文未说明截止时间，dueText 使用今天；没有明确教材位置时 textbookRef 使用待家长确认。"
        + "sourceExcerpt 必须尽量直接摘取对应老师原文，confidence 为 0 到 1。"
        + "title 要简洁，instruction 保留完成任务所需信息。";
  }

  static String buildInput(StudentEntity student, String sourceLabel, String text) {
    String grade = student.grade == null ? "" : student.grade;
    String semester = student.semester == null ? "" : student.semester;
    String textbooks = student.textbookSummary == null ? "" : student.textbookSummary;
    return "学生年级：" + grade + "\n学期：" + semester + "\n已知教材：" + textbooks
        + "\n来源：" + (sourceLabel == null ? "" : sourceLabel) + "\n老师原文：\n" + text;
  }

  static Optional<String> extractText(OpenAiResponse response) {
    if (response == null || response.output() == null) return Optional.empty();
    for (OpenAiOutput item : response.output()) {
      if (item == null || item.content() == null) continue;
      for (OpenAiContent content : item.content()) {
        if (content != null && "output_text".equals(content.type()) && content.text() != null) {
          String text = content.text().trim();
          if (!text.isEmpty()) return Optional.of(text);
        }
      }
    }
    return Optional.empty();
  }

  private static List<HomeworkOrganizerDtos.Candidate> toCandidates(StructuredResult result) {
    List<HomeworkOrganizerDtos.Candidate> output = new ArrayList<>();
    if (result == null || result.assignments() == null) return output;
    for (StructuredCandidate item : result.assignments()) {
      if (item == null || !supportedSubject(item.subject()) || blank(item.title())) continue;
      output.add(new HomeworkOrganizerDtos.Candidate(
          item.subject(), item.title().trim(), value(item.instruction(), item.title()),
          value(item.textbookRef(), "待家长确认"), value(item.dueText(), "今天"),
          value(item.sourceExcerpt(), item.title()), clamp(item.confidence())));
      if (output.size() >= 30) break;
    }
    return output;
  }

  private static boolean supportedSubject(String subject) {
    return "语文".equals(subject) || "数学".equals(subject) || "英语".equals(subject);
  }

  private static boolean blank(String value) { return value == null || value.isBlank(); }
  private static String value(String value, String fallback) { return blank(value) ? fallback : value.trim(); }
  private static double clamp(double value) { return Math.max(0.0, Math.min(1.0, value)); }

  private static Map<String, Object> structuredFormat() {
    Map<String, Object> candidateProperties = new LinkedHashMap<>();
    candidateProperties.put("subject", Map.of("type", "string", "enum", List.of("语文", "数学", "英语")));
    candidateProperties.put("title", Map.of("type", "string"));
    candidateProperties.put("instruction", Map.of("type", "string"));
    candidateProperties.put("textbookRef", Map.of("type", "string"));
    candidateProperties.put("dueText", Map.of("type", "string"));
    candidateProperties.put("sourceExcerpt", Map.of("type", "string"));
    candidateProperties.put("confidence", Map.of("type", "number", "minimum", 0, "maximum", 1));

    Map<String, Object> candidate = new LinkedHashMap<>();
    candidate.put("type", "object");
    candidate.put("additionalProperties", false);
    candidate.put("properties", candidateProperties);
    candidate.put("required", List.of("subject", "title", "instruction", "textbookRef", "dueText", "sourceExcerpt", "confidence"));

    Map<String, Object> schema = new LinkedHashMap<>();
    schema.put("type", "object");
    schema.put("additionalProperties", false);
    schema.put("properties", Map.of("assignments", Map.of("type", "array", "maxItems", 30, "items", candidate)));
    schema.put("required", List.of("assignments"));

    Map<String, Object> format = new LinkedHashMap<>();
    format.put("type", "json_schema");
    format.put("name", "homework_organization");
    format.put("strict", true);
    format.put("schema", schema);
    return format;
  }
}
