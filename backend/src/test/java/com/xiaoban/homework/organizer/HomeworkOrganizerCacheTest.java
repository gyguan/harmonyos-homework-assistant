package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import tools.jackson.databind.json.JsonMapper;

class HomeworkOrganizerCacheTest {
  private final JsonMapper json = JsonMapper.builder().build();
  private final OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
  private final AiProviderProperties properties = new AiProviderProperties();
  private final HomeworkTeacherExperienceService experiences = mock(HomeworkTeacherExperienceService.class);
  private final HomeworkOrganizerRuleService rules = mock(HomeworkOrganizerRuleService.class);
  private final HomeworkOrganizerCache cache = new HomeworkOrganizerCache(true, Duration.ofMinutes(5), 128, 8_388_608, Clock.systemUTC());
  private final ConfigurableHomeworkOrganizerModelClient client = new ConfigurableHomeworkOrganizerModelClient(
      properties, transport, json, experiences, rules, cache);

  private ConfigurableHomeworkOrganizerModelClientTest.TestStudent student() {
    var s = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    s.id = "student-cache"; s.familyId = UUID.randomUUID(); return s;
  }
  private String response(boolean image) {
    return json.writeValueAsString(Map.of("schemaVersion",2, "sourceBlocks",List.of(Map.of(
        "id",image ? "i1" : "t1", "text","数学口算20题", "inputKind",image ? "IMAGE" : "TEXT",
        "legibility","READABLE", "classification","TASK", "region",List.of())),
        "assignments",List.of(Map.of("subject","数学", "title","口算20题", "instruction","口算20题",
            "textbookRef","待家长确认", "taskDate",LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),
            "expectedMinutes",10, "confidence",.9, "sourceExcerpt","数学口算20题", "sourceBlockIds",List.of(image ? "i1" : "t1")))));
  }
  private void setup() {
    when(experiences.cacheVersion(any())).thenReturn("epoch-1");
    when(rules.snapshot(any(),any(),any())).thenReturn(new HomeworkOrganizerRuleService.Snapshot(List.of(), Map.of()));
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap())).thenReturn(Optional.of(response(false)));
    when(transport.completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap())).thenReturn(Optional.of(response(true)));
  }
  @Test void repeatsSkipProviderButNeverReuseAcrossScopeSourceTeacherContextOrVersions() {
    setup(); var s = student();
    var original = client.organizeDocument(s,"来源","数学口算20题").orElseThrow();
    try (var trace = HomeworkOrganizerTelemetry.open("different-batch","TEXT")) {
      assertEquals(original, client.organizeDocument(s,"来源","数学口算20题").orElseThrow());
      var data = trace.measurement();
      assertEquals(true, data.get("cacheHit")); assertEquals(0, data.get("callCount"));
      assertEquals(0L, data.get("tokensIn")); assertEquals(0L, data.get("tokensOut"));
      assertEquals(false, data.get("reviewTriggered"));
    }
    verify(transport,times(1)).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    // A distinct family, then a sibling, then precise source/teacher/context changes all miss.
    s.familyId = UUID.randomUUID(); client.organizeDocument(s,"来源","数学口算20题");
    s.id = "sibling"; client.organizeDocument(s,"来源","数学口算20题");
    client.organizeDocument(s,"来源","数学口算20题 ");
    client.organizeDocument(s,"来源\n[家长已确认老师：李老师]","数学口算20题");
    s.textbookSummary = "新版教材"; client.organizeDocument(s,"来源","数学口算20题");
    s.grade = "五年级"; client.organizeDocument(s,"来源","数学口算20题");
    s.semester = "下学期"; client.organizeDocument(s,"来源","数学口算20题");
    properties.setOrganizerModel("other-model"); client.organizeDocument(s,"来源","数学口算20题");
    properties.setBaseUrl("https://other.example"); client.organizeDocument(s,"来源","数学口算20题");
    properties.setDisableThinking(false); client.organizeDocument(s,"来源","数学口算20题");
    when(experiences.cacheVersion(any())).thenReturn("deactivated-experience");
    client.organizeDocument(s,"来源","数学口算20题");
    when(rules.snapshot(any(),any(),any())).thenReturn(new HomeworkOrganizerRuleService.Snapshot(List.of(),Map.of("BLACKBOARD","new prompt")));
    client.organizeDocument(s,"来源","数学口算20题");
    verify(transport,times(13)).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
  @Test void imageHashSupplementAndImageOnlyExperienceChangesInvalidate() {
    setup(); var s = student();
    client.organizeImage(s,"图片","data:image/png;base64,ORIGINAL1","");
    client.organizeImage(s,"图片","data:image/png;base64,ORIGINAL1","");
    verify(transport,times(1)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    client.organizeImage(s,"图片","data:image/png;base64,ORIGINAL2","");
    client.organizeImage(s,"图片","data:image/png;base64,ORIGINAL2","请核对");
    when(experiences.cacheVersion(any())).thenReturn("image-experience-disabled");
    client.organizeImage(s,"图片","data:image/png;base64,ORIGINAL1","");
    verify(transport,times(4)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
  @Test void riskyOrFailedResultsAndContextChangedDuringInferenceAreNeverCached() {
    setup(); var s = student();
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap())).thenReturn(Optional.empty());
    assertTrue(client.organizeDocument(s,"来源","数学口算20题").isEmpty());
    assertTrue(client.organizeDocument(s,"来源","数学口算20题").isEmpty());
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap()))
        .thenReturn(Optional.of(response(false)));
    // A non-covered source always stays risky even if the model repeats its answer.
    assertTrue(client.organizeDocument(s,"来源","数学口算20题\n语文朗读13页").orElseThrow().needsReview());
    assertTrue(client.organizeDocument(s,"来源","数学口算20题\n语文朗读13页").orElseThrow().needsReview());
    when(experiences.cacheVersion(any())).thenReturn("before", "after", "before", "after");
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap())).thenReturn(Optional.of(response(false)));
    client.organizeDocument(s,"来源","数学口算20题"); client.organizeDocument(s,"来源","数学口算20题");
    verify(transport,times(8)).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
  @Test void ttlLruByteBudgetAndDisabledCacheDoNotNeedSleep() {
    Clock now = Clock.fixed(Instant.parse("2026-10-20T00:00:00Z"),ZoneOffset.UTC);
    Clock moving = mock(Clock.class); when(moving.millis()).thenReturn(now.millis());
    var bounded = new HomeworkOrganizerCache(true,Duration.ofSeconds(5),2,9,moving);
    bounded.put("a","中"); bounded.put("b","文");
    assertTrue(bounded.get("a").isPresent()); bounded.put("c","字");
    assertTrue(bounded.get("b").isEmpty()); // LRU, not insertion order
    bounded.put("big","超过字节预算"); assertTrue(bounded.get("big").isEmpty());
    bounded.put("d","test"); assertTrue(bounded.get("a").isEmpty());
    when(moving.millis()).thenReturn(now.millis()+5000); bounded.evictExpired();
    assertTrue(bounded.get("c").isEmpty()); assertTrue(bounded.get("d").isEmpty());
    var disabled = new HomeworkOrganizerCache(false,Duration.ofMinutes(1),2,100,now);
    disabled.put("key","value"); assertTrue(disabled.get("key").isEmpty());
  }
}
