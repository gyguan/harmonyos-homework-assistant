package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class HomeworkSourceEvidenceTest {
  static HomeworkOrganizerDtos.Candidate task(String title, String... refs) {
    return new HomeworkOrganizerDtos.Candidate("数学", title, title, "待家长确认", "2026-10-19", 10,
        title, .8, "", "", "", 0, "", List.of(refs));
  }
  static HomeworkSourceDocument.Block block(String id, String text, String classification) {
    return new HomeworkSourceDocument.Block(id, text, "IMAGE", null, 0, List.of(), "READABLE", classification);
  }
  @Test void omittedTaskStillHasIndependentImageEvidenceAndNotificationIsNotOmission() {
    var client = new ConfigurableHomeworkOrganizerModelClient(new com.xiaoban.homework.ai.AiProviderProperties(),
        null, JsonMapper.builder().build());
    String output = """
        {"schemaVersion":2,"sourceBlocks":[
          {"id":"i1","text":"数学口算20题","inputKind":"IMAGE","imageIndex":0,"legibility":"READABLE","classification":"TASK"},
          {"id":"i2","text":"语文朗读13页","inputKind":"IMAGE","imageIndex":0,"legibility":"READABLE","classification":"TASK"},
          {"id":"i3","text":"周五家长会","inputKind":"IMAGE","imageIndex":0,"legibility":"READABLE","classification":"NON_TASK"}],
          "assignments":[{"subject":"数学","title":"口算20题","instruction":"口算20题","expectedMinutes":10,
          "sourceExcerpt":"数学口算20题","sourceBlockIds":["i1"]}]}
        """;
    var result = client.parseImageOutput(output).orElseThrow();
    assertTrue(result.recognizedText().contains("语文朗读13页"));
    assertEquals(3, result.sourceDocument().blocks().size());
    assertTrue(result.qualityFlags().stream().anyMatch(f -> f.code().equals("POSSIBLE_OMISSION") && f.sourceBlockIds().equals(List.of("i2"))));
    assertFalse(result.qualityFlags().stream().anyMatch(f -> f.sourceBlockIds().contains("i3")));
  }
  @Test void originalTextCannotBeRewrittenAndOneBlockCanSupportManyTasks() {
    var original = HomeworkSourceDocument.text("原文第一行\n口算与订正\n");
    var modified = block("t1", "篡改原文", "NON_TASK");
    var unchanged = block("t2", "口算与订正", "TASK");
    var result = HomeworkSourceEvidence.reconcileText(original, List.of(modified, unchanged));
    assertEquals(original.originalText(), result.originalText());
    assertEquals("原文第一行", result.blocks().getFirst().text());
    assertEquals("UNRESOLVED", result.blocks().getFirst().classification());
    var doc = new HomeworkSourceDocument(2, "TEXT", "口算与订正", List.of(unchanged));
    assertTrue(HomeworkSourceEvidence.flags(doc, List.of(task("口算", "t2"), task("订正", "t2"))).isEmpty());
  }
  @Test void unknownAndMissingReferencesAreFlaggedWithoutDeletingTasks() {
    var doc = new HomeworkSourceDocument(2, "IMAGE", "", List.of(block("i1", "真实文字", "TASK")));
    var items = List.of(task("无依据任务", "fake"), task("没有关联"));
    var flags = HomeworkSourceEvidence.flags(doc, items);
    assertTrue(flags.stream().anyMatch(f -> f.code().equals("UNKNOWN_SOURCE_REFERENCE")));
    assertTrue(flags.stream().anyMatch(f -> f.code().equals("TASK_WITHOUT_EVIDENCE")));
    assertTrue(flags.stream().anyMatch(f -> f.code().equals("POSSIBLE_OMISSION")));
    assertEquals(2, items.size());
  }
  @Test void oldApiJsonStillDeserializesAndRetainsFields() {
    var json = JsonMapper.builder().build();
    var response = json.readValue("{\"assignments\":[{\"subject\":\"数学\",\"title\":\"口算\",\"expectedMinutes\":10,\"confidence\":0.8,\"duplicateConfidence\":0}],\"mode\":\"AI\",\"needsReview\":false}", HomeworkOrganizerDtos.Response.class);
    assertTrue(response.assignments().getFirst().sourceBlockIds().isEmpty());
    assertTrue(json.writeValueAsString(response).contains("sourceExcerpt"));
  }
}
