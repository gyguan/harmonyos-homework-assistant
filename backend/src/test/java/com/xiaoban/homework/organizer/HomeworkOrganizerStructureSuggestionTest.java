package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

import com.xiaoban.homework.assignment.AssignmentEntity;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class HomeworkOrganizerStructureSuggestionTest {
  private static HomeworkOrganizerAiSnapshotEntity original(String id, String title, String source) {
    var e = new HomeworkOrganizerAiSnapshotEntity();
    e.candidateId = id;
    e.title = title;
    e.sourceExcerpt = source;
    return e;
  }
  private static AssignmentEntity published(String title, String source) {
    var e = mock(AssignmentEntity.class);
    e.title = title;
    e.sourceExcerpt = source;
    return e;
  }

  @Test
  void exactSameEvidenceSuggestsSplitWithoutTurningItIntoEstablishedError() {
    String source = "1.背诵第4课 2.抄写生字";
    var old = original("ai-batch-1", "背诵并抄写", source);
    Map<String, AssignmentEntity> finalItems = new LinkedHashMap<>();
    finalItems.put("ai-batch-1", published("背诵第4课", source));
    finalItems.put("manual-1", published("抄写生字", source));
    var result = HomeworkOrganizerReviewDifferenceService.structureCandidates(List.of(old), finalItems);
    assertEquals(1, result.size());
    assertEquals("SPLIT_SUSPECTED", result.getFirst().changeType());
    assertEquals("structure", result.getFirst().fieldName());
    assertTrue(result.getFirst().afterValue().contains("抄写生字"));
  }

  @Test
  void exactSameEvidenceSuggestsMergeIfTwoOriginalsBecomeOne() {
    String source = "朗读同一课文并录音提交";
    var first = original("ai-batch-1", "朗读课文", source);
    var second = original("ai-batch-2", "录音提交", source);
    var published = Map.of("ai-batch-1", published("朗读并录音提交", source));
    var result = HomeworkOrganizerReviewDifferenceService.structureCandidates(
        List.of(first, second), published);
    assertEquals(1, result.size());
    assertEquals("MERGE_SUSPECTED", result.getFirst().changeType());
  }

  @Test
  void ambiguousOrShortEvidenceDoesNotInventSplitMerge() {
    var a = original("ai-a", "语文作业", "读课文");
    var b = original("ai-b", "数学作业", "完成习题第13页");
    var result = HomeworkOrganizerReviewDifferenceService.structureCandidates(
        List.of(a, b), Map.of(
          "ai-a", published("朗读", "读课文"),
          "manual-2", published("抄写", "全班今日作业，包括朗读")));
    assertTrue(result.isEmpty());
  }
}
