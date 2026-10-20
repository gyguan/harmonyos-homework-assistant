package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.json.JsonMapper;
import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;

class HomeworkRiskReviewTest {
  private final JsonMapper json=JsonMapper.builder().build();
  private Map<String,Object> block(String id, String text) {
    return Map.of("id",id,"text",text,"inputKind","TEXT","legibility","READABLE","classification","TASK","region",List.of());
  }
  private Map<String,Object> task(String title, String id) {
    return Map.of("subject","数学","title",title,"instruction",title,"textbookRef","待家长确认",
        "taskDate",LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),"expectedMinutes",10,
        "sourceExcerpt",title,"confidence",1.0,"sourceBlockIds",List.of(id));
  }
  private String primary(List<Map<String,Object>> blocks, List<Map<String,Object>> tasks) {
    return json.writeValueAsString(Map.of("schemaVersion",2,"sourceBlocks",blocks,"assignments",tasks,"appliedExperienceIds",List.of()));
  }
  @Test void lowRiskUsesOneCallEvenWithRelevantExperienceAndDefaultConfidence() {
    var transport=mock(OpenAiCompatibleTransport.class); var exp=mock(HomeworkTeacherExperienceService.class);
    var student=new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    when(exp.retrieve(any(),anyString(),anyString(),eq(false))).thenReturn(new HomeworkTeacherExperienceService.Retrieval("相关经验",List.of()));
    var draft=new java.util.HashMap<>(task("口算20题","t1")); draft.remove("confidence");
    var output=primary(List.of(block("t1","数学：口算20题")),List.of(draft));
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap())).thenReturn(Optional.of(output));
    var result=new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(),transport,json,exp)
        .organizeDocument(student,"来源","数学：口算20题").orElseThrow();
    assertFalse(result.needsReview());
    verify(transport,times(1)).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
  @Test void riskWithoutExperienceUsesOneTargetedReviewAndKeepsUntouchedDraft() {
    var transport=mock(OpenAiCompatibleTransport.class);
    String output=primary(List.of(block("t1","数学：口算20题"),block("t2","数学：订正昨天错题")),List.of(task("口算20题","t1")));
    String review=json.writeValueAsString(Map.of("reviewVersion",2,"corrections",List.of(),
        "additions",List.of(Map.of("assignment",task("订正昨天错题","t2"),"reason","来源含遗漏的订正任务")),"blockDecisions",List.of(),"appliedExperienceIds",List.of()));
    when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap()))
        .thenAnswer(inv -> Optional.of("homework_risk_review".equals(inv.getArgument(4)) ? review : output));
    var result=new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(),transport,json)
        .organizeDocument(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"来源","数学：口算20题\n数学：订正昨天错题").orElseThrow();
    assertEquals(2,result.assignments().size()); assertEquals("口算20题",result.assignments().getFirst().title());
    assertFalse(result.needsReview());
    var document = result.sourceDocument();
    assertEquals(3, document.schemaVersion());
    assertEquals("数学：口算20题\n数学：订正昨天错题", document.originalText());
    assertEquals(1, document.revisions().size());
    var revision = document.revisions().getFirst();
    assertEquals("TEXT_RISK_REVIEW", revision.kind());
    assertEquals("t2", revision.before().id());
    assertEquals(revision.before(), revision.after());
    var addition = revision.changes().getFirst();
    assertEquals(1, addition.assignmentIndex());
    assertNull(addition.before());
    assertEquals(result.assignments().get(1), addition.after());
    assertEquals("来源含遗漏的订正任务", addition.reason());
    assertEquals(document, json.readValue(json.writeValueAsString(document), HomeworkSourceDocument.class));
    var inputs=ArgumentCaptor.forClass(String.class);
    verify(transport,times(2)).complete(anyString(),anyString(),inputs.capture(),anyInt(),anyString(),anyMap());
    assertTrue(inputs.getAllValues().get(1).contains("t2"));
    assertFalse(inputs.getAllValues().get(1).contains("口算20题"));
  }
  @Test void reviewFailureOrNewFabricationPreservesDraftAndExposesRisk() {
    for (String reply : List.of("bad json", json.writeValueAsString(Map.of("reviewVersion",2,"corrections",List.of(),
        "additions",List.of(Map.of("assignment",task("订正99题","t2"),"reason","补任务")),"blockDecisions",List.of(),"appliedExperienceIds",List.of())))) {
      var transport=mock(OpenAiCompatibleTransport.class);
      String first=primary(List.of(block("t1","数学：口算20题"),block("t2","数学：订正昨天错题")),List.of(task("口算20题","t1")));
      when(transport.complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap()))
          .thenAnswer(inv -> Optional.of("homework_risk_review".equals(inv.getArgument(4)) ? reply : first));
      var result=new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(),transport,json)
          .organizeDocument(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"来源","数学：口算20题\n数学：订正昨天错题").orElseThrow();
      assertEquals(1,result.assignments().size()); assertTrue(result.needsReview());
      assertTrue(result.qualityFlags().stream().anyMatch(f -> f.code().startsWith("REVIEW_")));
      verify(transport,times(2)).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    }
  }
  @Test void correctionAndClassificationKeepOriginalEvidenceAndModelReasons() {
    var transport = mock(OpenAiCompatibleTransport.class);
    var unresolved = new java.util.HashMap<>(block("t1", "数学：口算20题"));
    unresolved.put("classification", "UNRESOLVED");
    String first = primary(List.of(unresolved), List.of(task("口算99题", "t1")));
    String review = json.writeValueAsString(Map.of("reviewVersion", 2,
        "corrections", List.of(Map.of("assignmentIndex", 0, "assignment", task("口算20题", "t1"), "reason", "原文数量为20")),
        "additions", List.of(), "blockDecisions", List.of(Map.of("blockId", "t1", "classification", "TASK", "reason", "来源明确要求完成任务")),
        "appliedExperienceIds", List.of()));
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenAnswer(inv -> Optional.of("homework_risk_review".equals(inv.getArgument(4)) ? review : first));
    var result = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport, json)
        .organizeDocument(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(), "来源", "数学：口算20题").orElseThrow();
    assertFalse(result.needsReview());
    var revision = result.sourceDocument().revisions().getFirst();
    assertEquals("UNRESOLVED", revision.before().classification());
    assertEquals("TASK", revision.after().classification());
    assertEquals(revision.before().text(), revision.after().text());
    assertEquals("来源明确要求完成任务", revision.reason());
    assertEquals("口算99题", revision.changes().getFirst().before().title());
    assertEquals("口算20题", revision.changes().getFirst().after().title());
    assertEquals("原文数量为20", revision.changes().getFirst().reason());
    verify(transport, times(2)).complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap());
  }

  @Test void missingBlankOrOversizedAdditionReasonNeverAppliesOrLeaksPartialAudit() {
    for (Object addition : List.of(task("订正昨天错题", "t2"),
        Map.of("assignment", task("订正昨天错题", "t2"), "reason", " "),
        Map.of("assignment", task("订正昨天错题", "t2"), "reason", "长".repeat(301)))) {
      var transport = mock(OpenAiCompatibleTransport.class);
      String first = primary(List.of(block("t1", "数学：口算20题"), block("t2", "数学：订正昨天错题")), List.of(task("口算20题", "t1")));
      String review = json.writeValueAsString(Map.of("reviewVersion", 2, "corrections", List.of(),
          "additions", List.of(addition), "blockDecisions", List.of(), "appliedExperienceIds", List.of()));
      when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
          .thenAnswer(inv -> Optional.of("homework_risk_review".equals(inv.getArgument(4)) ? review : first));
      var result = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport, json)
          .organizeDocument(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(), "来源", "数学：口算20题\n数学：订正昨天错题").orElseThrow();
      assertTrue(result.needsReview());
      assertEquals(1, result.assignments().size());
      assertTrue(result.sourceDocument().revisions().isEmpty());
      verify(transport, times(2)).complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap());
    }
  }

  @Test void confidenceNeverOverridesEvidenceAndJavaNeverRewritesBusinessMeaning() {
    var validator=new HomeworkQualityValidator();
    var doc=new HomeworkSourceDocument(2,"TEXT","数学：口算20题",List.of(
        new HomeworkSourceDocument.Block("t1","数学：口算20题","TEXT",null,null,List.of(),"READABLE","TASK")));
    var wrong=new HomeworkOrganizerDtos.Candidate("数学","口算99题","口算99题","待家长确认",
        LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),10,"口算20题",1,"","","",0,"",List.of("t1"));
    var assessment=validator.validate(doc,List.of(wrong),HomeworkOrganizerDtos.ExperienceUsage.empty());
    assertEquals(HomeworkQualityValidator.Risk.HIGH,assessment.risk());
    assertTrue(assessment.flags().stream().anyMatch(f->f.code().equals("UNSUPPORTED_NUMBER")));
    assertEquals("口算99题",wrong.title());
    for (String text : List.of("摘抄（4+2）","绘本","任意老师的新简写")) {
      var result=ConfigurableHomeworkOrganizerModelClient.toCandidates(new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
          new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate("语文",text,text,"待家长确认","今天",10,text,1.0))));
      assertEquals(text,result.candidates().getFirst().title());
    }
  }
}
