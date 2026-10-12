package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class DuplicateReviewProviderAdapterTest {
  private final JsonMapper mapper = JsonMapper.builder().build();

  @Test
  void acceptsOnlyCanonicalReviewResponse() throws Exception {
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
  void stillNormalizesProviderEnvelopeButNotBusinessFieldAliases() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, """
        {"result":{"matches":[{"candidateIndex":"0","duplicateAssignmentId":"a-1",
        "confidence":"0.91","reason":"页码题号一致"}]}}
        """);

    assertEquals("a-1", adapted.review().matches().getFirst().duplicateAssignmentId());
    assertTrue(adapted.shape().contains("wrapper:result"));
    assertTrue(adapted.coercedPaths().contains("$.matches[0].candidateIndex"));
    assertTrue(adapted.coercedPaths().contains("$.matches[0].confidence"));
  }

  @Test
  void rejectsModelSpecificAliasesSoContractRunnerCanRepairThem() {
    var error = assertThrows(IllegalArgumentException.class, () ->
        DuplicateReviewProviderAdapter.adapt(mapper, """
            {"matches":[{"candidate":"C0","existing_task_id":"assignment-456","confidence":0.94}]}
            """));

    assertTrue(error.getMessage().contains("unexpected fields"));
  }

  @Test
  void rejectsMissingReasonAndNullMatchesInsteadOfInventingBusinessFields() {
    assertThrows(IllegalArgumentException.class, () ->
        DuplicateReviewProviderAdapter.adapt(mapper, """
            {"matches":[{"candidateIndex":0,"duplicateAssignmentId":"a-1","confidence":0.91}]}
            """));
    assertThrows(IllegalArgumentException.class, () ->
        DuplicateReviewProviderAdapter.adapt(mapper, "{" + "\"matches\":null}"));
  }

  @Test
  void acceptsExplicitNoMatchContract() throws Exception {
    var adapted = DuplicateReviewProviderAdapter.adapt(mapper, "{" + "\"matches\":[]}");

    assertTrue(adapted.review().matches().isEmpty());
  }
}
