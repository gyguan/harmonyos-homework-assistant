package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.json.JsonMapper;

class HomeworkFeedbackExperienceModelTest {
  @Test void modelReceivesParentEvidenceAndReturnsGeneralizedStructuredInterpretation() {
    var transport = mock(OpenAiCompatibleTransport.class);
    var properties = new AiProviderProperties();
    properties.setOrganizerModel("feedback-model");
    when(transport.available("feedback-model")).thenReturn(true);
    when(transport.complete(eq("feedback-model"), anyString(), anyString(),
        eq(600), eq("homework_feedback_experience"), anyMap()))
        .thenReturn(Optional.of("""
          {"reusable":true,"cue":"摘抄",
           "applyWhen":"语文摘抄任务中括号内有两个数量时",
           "guidance":"前一个数为本次好词数量，后一个数为本次好句数量，请在标题和要求中展开",
           "confidence":0.97}
          """));
    var model = new HomeworkFeedbackExperienceModel(transport, properties,
        JsonMapper.builder().build());
    var feedback = new HomeworkOrganizerFeedbackEntity();
    feedback.feedbackTypeCode = "WRONG_CONTENT";
    feedback.details = "4+2表示4个好词，2个好句";
    feedback.currentTitle = "完成摘抄（4+2）";
    var original = new HomeworkOrganizerAiSnapshotEntity();
    original.subject = "语文";
    original.teacherName = "";
    original.title = "完成摘抄（4+2）";
    original.instruction = "完成摘抄（4+2）";
    original.sourceExcerpt = "摘抄：（4+2）";

    var result = model.extract(feedback, original).orElseThrow();
    assertTrue(result.reusable());
    assertEquals("摘抄", result.cue());
    assertTrue(result.guidance().contains("前一个数为本次好词数量"));
    var prompt = ArgumentCaptor.forClass(String.class);
    var input = ArgumentCaptor.forClass(String.class);
    verify(transport).complete(eq("feedback-model"), prompt.capture(), input.capture(),
        eq(600), eq("homework_feedback_experience"), anyMap());
    assertTrue(prompt.getValue().contains("提炼一条可复用"));
    assertTrue(prompt.getValue().contains("变量"));
    assertTrue(input.getValue().contains("4+2表示4个好词"));
    assertTrue(input.getValue().contains("摘抄：（4+2）"));
  }

  @Test void malformedModelJsonNeverProducesAnActiveRule() {
    var transport = mock(OpenAiCompatibleTransport.class);
    var properties = new AiProviderProperties();
    when(transport.available(properties.getOrganizerModel())).thenReturn(true);
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(),
        anyString(), anyMap())).thenReturn(Optional.of("{not-json"));
    var model = new HomeworkFeedbackExperienceModel(transport, properties,
        JsonMapper.builder().build());
    var feedback = new HomeworkOrganizerFeedbackEntity();
    var original = new HomeworkOrganizerAiSnapshotEntity();
    assertTrue(model.extract(feedback, original).isEmpty());
  }
}
