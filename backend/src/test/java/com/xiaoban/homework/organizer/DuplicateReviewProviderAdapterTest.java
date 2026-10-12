package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class DuplicateReviewProviderAdapterTest {
  private final JsonMapper mapper = JsonMapper.builder().build();

  @Test
  void acceptsCanonicalReviewResponse() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"matches":[{"candidateIndex":0,"duplicateAssignmentId":"a-1",
        "confidence":0.91,"reason":"页码题号一致"}]}
        """);

    var decision = adapted.review().matches().getFirst();
    assertEquals(0, decision.candidateIndex());
    assertEquals("a-1", decision.duplicateAssignmentId());
    assertEquals(0.91, decision.confidence());
    assertEquals("页码题号一致", decision.reason());
  }

  @Test
  void acceptsQwenStyleWrappersAndScalarVariations() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"result":{"matches":{
          "candidate_index":"C0",
          "duplicate_assignment_id":{"value":"a-math"},
          "score":"91%",
          "explanation":{"text":"页码、题号和完成要求一致"}
        }}}
        """);

    var decision = adapted.review().matches().getFirst();
    assertEquals(0, decision.candidateIndex());
    assertEquals("a-math", decision.duplicateAssignmentId());
    assertEquals(0.91, decision.confidence());
    assertTrue(decision.reason().contains("页码"));
    assertTrue(adapted.shape().contains("wrapper:result"));
    assertTrue(adapted.coercedPaths().contains("$.matches"));
    assertTrue(adapted.coercedPaths().contains("$.matches[0].candidateIndex"));
    assertTrue(adapted.coercedPaths().contains("$.matches[0].confidence"));
  }

  @Test
  void acceptsObservedQwenCandidateAndExistingIdAliases() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"matches":[{"candidate_id":"C0","existing_id":"assignment-123","confidence":0.93}]}
        """);

    var decision = adapted.review().matches().getFirst();
    assertEquals(0, decision.candidateIndex());
    assertEquals("assignment-123", decision.duplicateAssignmentId());
    assertEquals(0.93, decision.confidence());
    assertEquals("AI语义判重", decision.reason());
  }

  @Test
  void acceptsObservedQwenCandidateAndExistingTaskIdAliases() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"matches":[{"candidate":"C0","existing_task_id":"assignment-456","confidence":0.94}]}
        """);

    var decision = adapted.review().matches().getFirst();
    assertEquals(0, decision.candidateIndex());
    assertEquals("assignment-456", decision.duplicateAssignmentId());
    assertEquals(0.94, decision.confidence());
    assertEquals("AI语义判重", decision.reason());
  }

  @Test
  void acceptsStringifiedMatchesAndMissingReason() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper,
        "{\"matches\":\"[{\\\"candidateIndex\\\":\\\"0\\\","
            + "\\\"duplicateAssignmentId\\\":\\\"a-2\\\","
            + "\\\"confidence\\\":\\\"0.86\\\"}]\"}");

    var decision = adapted.review().matches().getFirst();
    assertEquals(0, decision.candidateIndex());
    assertEquals("a-2", decision.duplicateAssignmentId());
    assertEquals(0.86, decision.confidence());
    assertEquals("AI语义判重", decision.reason());
  }

  @Test
  void treatsExplicitNullMatchesAsNoDuplicate() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"matches":null}
        """);

    assertTrue(adapted.review().matches().isEmpty());
    assertTrue(adapted.coercedPaths().contains("$.matches"));
  }
}
