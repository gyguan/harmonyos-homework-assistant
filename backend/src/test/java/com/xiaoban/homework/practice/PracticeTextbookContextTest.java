package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PracticeTextbookContextTest {
  @Test
  void extractsRequestedSubjectFromMultiSubjectSummary() {
    String summary = "语文：人教版二年级上册；数学：北师大版二年级上册；英语：外研版二年级上册";
    assertEquals("北师大版二年级上册", PracticeTextbookContext.extract(summary, "MATH"));
  }

  @Test
  void preservesLegacySingleSubjectSummary() {
    assertEquals(
        "人教版数学二年级上册",
        PracticeTextbookContext.extract("人教版数学二年级上册", "MATH"));
  }

  @Test
  void comparesOnlyRequestedSubject() {
    String reference = PracticeTextbookContext.extract(
        "语文：人教版；数学：北师大版；英语：外研版", "MATH");
    assertTrue(PracticeTextbookContext.compatible(
        reference,
        "语文：苏教版；数学：北师大版；英语：人教版",
        "MATH"));
    assertFalse(PracticeTextbookContext.compatible(
        reference,
        "语文：人教版；数学：人教版；英语：外研版",
        "MATH"));
  }
}
