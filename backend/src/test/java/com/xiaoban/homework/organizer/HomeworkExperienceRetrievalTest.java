package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class HomeworkExperienceRetrievalTest {
  static HomeworkTeacherExperienceEntity experience(UUID family, String student, String cue, String teacher, String subject) {
    var e = new HomeworkTeacherExperienceEntity(); e.id=UUID.randomUUID(); e.familyId=family; e.studentId=student;
    e.teacherName=teacher; e.subject=subject; e.cue=cue; e.interpretation="经确认的通用说明";
    e.exampleSource=cue; e.exampleResult="确认结果"; e.origin="FEEDBACK_AI"; e.updatedAt=Instant.now(); return e;
  }
  @Test void ranksRelevantRulesAndDoesNotCarryUnrelatedTeacherSubjectOrFamily() {
    var student=new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.id="child"; student.familyId=UUID.randomUUID();
    var relevant=experience(student.familyId,"child","摘抄：（4+2）","王老师","语文");
    var unrelated=experience(student.familyId,"child","口算","王老师","语文");
    var foreign=experience(UUID.randomUUID(),"child","摘抄","王老师","语文");
    var another=experience(student.familyId,"other","摘抄","王老师","语文");
    var subject=experience(student.familyId,"child","摘抄","王老师","数学");
    var teacher=experience(student.familyId,"child","摘抄","李老师","语文");
    var repository=mock(HomeworkTeacherExperienceRepository.class);
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(student.familyId,student.id))
        .thenReturn(List.of(unrelated, foreign, another, subject, teacher, relevant));
    var service=new HomeworkTeacherExperienceService(repository,mock(StudentRepository.class));
    var result=service.retrieve(student,"[家长已确认老师：王老师]","语文：摘抄：（3+2）",false);
    assertEquals(List.of(relevant.id.toString()),result.selected().stream().map(HomeworkTeacherExperienceService.Selected::id).toList());
    assertTrue(result.context().contains("变量和数量必须取本次原文的值"));
    assertTrue(result.context().length()<2400);
    String before=result.selected().getFirst().version();
    relevant.interpretation="更新后的确认说明";
    assertNotEquals(before,service.retrieve(student,"王老师","语文：摘抄：（3+2）",false).selected().getFirst().version());
    relevant.active=false;
    assertTrue(service.retrieve(student,"王老师","语文：摘抄：（3+2）",false).selected().isEmpty());
  }
  @Test void configurableTopKAndBudgetSkipOversizeRuleWithoutTruncatingMeaning() {
    var student=new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(); student.id="s"; student.familyId=UUID.randomUUID();
    var huge=experience(student.familyId,"s","测试","王老师","语文"); huge.interpretation="长".repeat(2500);
    var fit=experience(student.familyId,"s","测试","王老师","语文");
    var other=experience(student.familyId,"s","测试","王老师","语文");
    var repo=mock(HomeworkTeacherExperienceRepository.class);
    when(repo.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(student.familyId,student.id)).thenReturn(List.of(huge,fit,other));
    var svc=new HomeworkTeacherExperienceService(repo,mock(StudentRepository.class));
    ReflectionTestUtils.setField(svc,"topK",1);
    ReflectionTestUtils.setField(svc,"maxContextChars",900);
    var result=svc.retrieve(student,"王老师","语文：测试",false);
    assertEquals(1,result.selected().size()); assertFalse(result.context().contains("长长")); assertTrue(result.context().length()<=900);
    assertTrue(svc.retrieve(student,"图片","",true).selected().isEmpty());
  }
  @Test void modelDeclaredApplicationRequiresRetrievedIdSubjectAndSourceReference() {
    String id=UUID.randomUUID().toString();
    var retrieval=new HomeworkTeacherExperienceService.Retrieval("context",List.of(
        new HomeworkTeacherExperienceService.Selected(id,"v1","数学","口算")));
    var block=HomeworkSourceEvidenceTest.block("i1","口算20题","TASK");
    var doc=new HomeworkSourceDocument(2,"IMAGE","",List.of(block));
    var valid=ConfigurableHomeworkOrganizerModelClient.usage(retrieval,List.of(id,"invented"),doc,List.of(HomeworkSourceEvidenceTest.task("口算20题","i1")));
    assertEquals(List.of(id),valid.appliedExperienceIds()); assertEquals(List.of("invented"),valid.unsupportedAppliedExperienceIds());
    var noEvidence=ConfigurableHomeworkOrganizerModelClient.usage(retrieval,List.of(id),doc,List.of(HomeworkSourceEvidenceTest.task("口算20题")));
    assertTrue(noEvidence.appliedExperienceIds().isEmpty());
  }
}
