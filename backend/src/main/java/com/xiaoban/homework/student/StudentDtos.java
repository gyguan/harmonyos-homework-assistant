package com.xiaoban.homework.student;

import jakarta.validation.constraints.NotBlank;

public final class StudentDtos {
  private StudentDtos() {}
  public record Upsert(@NotBlank String id, @NotBlank String name, @NotBlank String grade,
      @NotBlank String className, @NotBlank String semester, String textbookSummary) {}
  public record Response(String id, String name, String grade, String className, String semester, String textbookSummary) {
    static Response from(StudentEntity e) { return new Response(e.id, e.name, e.grade, e.className, e.semester, e.textbookSummary); }
  }
}
