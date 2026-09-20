package com.xiaoban.homework.practice;

import java.util.List;

public final class PracticeContentCatalog {
  private PracticeContentCatalog() {}

  public record Catalog(
      int schemaVersion,
      String catalogId,
      String generatedBy,
      List<Paper> papers) {}

  public record Paper(
      String id,
      int version,
      String grade,
      String subject,
      String title,
      String description,
      String difficulty,
      int questionCount,
      int estimatedMinutes,
      List<String> tags,
      String sourceType,
      String status,
      List<Question> questions) {}

  public record Question(
      String id,
      int orderNo,
      String type,
      String stem,
      List<Option> options,
      String answerSpec,
      String explanation,
      List<String> hints,
      List<String> tags) {}

  public record Option(String key, String label) {}
}
