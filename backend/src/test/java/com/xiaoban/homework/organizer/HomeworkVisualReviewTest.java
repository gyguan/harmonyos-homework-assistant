package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import org.springframework.test.util.ReflectionTestUtils;
import tools.jackson.databind.json.JsonMapper;
import javax.imageio.ImageIO;

class HomeworkVisualReviewTest {
  private final JsonMapper json=JsonMapper.builder().build();
  private String image() throws Exception {
    var pixels=new BufferedImage(8,8,BufferedImage.TYPE_INT_ARGB);
    for(int y=0;y<8;y++)for(int x=0;x<8;x++)pixels.setRGB(x,y,0xff000000 | (x<<16) | (y<<8));
    return "data:image/png;base64,"+Base64.getEncoder().encodeToString(HomeworkImageOrientationTest.encoded(pixels,"PNG"));
  }
  private Map<String,Object> block(String id,boolean unclear) {
    return Map.of("id",id,"text",unclear ? "看不清" : "数学口算20题","inputKind","IMAGE","imageIndex",0,
        "region",unclear ? List.of(.25,.25,.5,.5) : List.of(0.,0.,.25,.25),
        "legibility",unclear ? "UNCLEAR" : "READABLE","classification",unclear ? "UNRESOLVED" : "TASK");
  }
  private Map<String,Object> task(String id,String title) {
    return Map.of("subject","数学","title",title,"instruction",title,"textbookRef","待家长确认",
        "taskDate",LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),"expectedMinutes",10,"confidence",.9,
        "sourceExcerpt","数学"+title,"sourceBlockIds",List.of(id));
  }
  private Map<String,Object> reading(String text,String legibility) {
    return Map.of("blockId","i2","text",text,"legibility",legibility,"classification","TASK","reason","局部可辨认来源");
  }
  private String primary(List<Map<String,Object>> blocks,List<Map<String,Object>> tasks) {
    return json.writeValueAsString(Map.of("schemaVersion",2,"sourceBlocks",blocks,"assignments",tasks));
  }
  private String patch(Map<String,Object> reading,List<?> corrections,List<?> additions) {
    return json.writeValueAsString(Map.of("visualReviewVersion",1,"reading",reading,"corrections",corrections,
        "additions",additions,"appliedExperienceIds",List.of()));
  }
  private ConfigurableHomeworkOrganizerModelClient client(OpenAiCompatibleTransport transport,String primary,String review) {
    when(transport.completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap()))
        .thenAnswer(inv->Optional.of("homework_image_risk_review".equals(inv.getArgument(5))?review:primary));
    return new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(),transport,json);
  }
  @Test void unclearLocatedBlockGetsOnlyOnePixelExactCropReviewAndAuditWithoutTouchingSiblings() throws Exception {
    var transport=mock(OpenAiCompatibleTransport.class);
    var initial=task("i1","口算20题"); var addition=task("i2","订正5题");
    var client=client(transport,primary(List.of(block("i1",false),block("i2",true)),List.of(initial)),
        patch(reading("数学订正5题","READABLE"),List.of(),List.of(Map.of("assignment",addition,"reason","局部发现遗漏任务"))));
    var result=client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
    assertFalse(result.needsReview()); assertEquals(2,result.assignments().size());
    assertEquals("口算20题",result.assignments().getFirst().title()); assertEquals("订正5题",result.assignments().getLast().title());
    assertEquals(3,result.sourceDocument().schemaVersion()); var revision=result.sourceDocument().revisions().getFirst();
    assertEquals("看不清",revision.before().text()); assertEquals("数学订正5题",revision.after().text());
    assertEquals(1,revision.changes().size()); assertNotNull(revision.changes().getFirst().reason());
    var images=ArgumentCaptor.forClass(String.class); var inputs=ArgumentCaptor.forClass(String.class);
    verify(transport,times(2)).completeWithImage(anyString(),anyString(),inputs.capture(),images.capture(),anyInt(),anyString(),anyMap());
    verify(transport,never()).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    var crop=ImageIO.read(new ByteArrayInputStream(Base64.getDecoder().decode(images.getAllValues().get(1).split(",",2)[1])));
    assertEquals(4,crop.getWidth()); assertEquals(4,crop.getHeight());
    assertEquals(0xff020200,crop.getRGB(0,0)); assertEquals(0xff050500,crop.getRGB(3,3));
    assertFalse(inputs.getAllValues().get(1).contains("口算20题"));
    var restored=json.readValue(json.writeValueAsString(result),HomeworkOrganizerDtos.ImageResponse.class);
    assertEquals(result,restored);
  }
  @Test void badOrStillUnclearOrFabricatedPatchKeepsFirstDraftAndNeverAddsThirdInference() throws Exception {
    var badReplies=List.of("invalid-json",patch(reading("仍看不清","UNCLEAR"),List.of(),List.of()),
        patch(reading("数学订正5题","READABLE"),List.of(),List.of(Map.of("assignment",task("i2","订正99题"),"reason","无依据数字"))),
        patch(reading("数学订正5题","READABLE"),List.of(Map.of("assignmentIndex",0,"assignment",task("i2","订正5题"),"reason","越界修改")),List.of()),
        patch(reading("数学订正5题","READABLE"),List.of(),List.of(Map.of("assignment",task("i2","订正5题"),"reason",""))));
    for(String reply:badReplies) {
      var transport=mock(OpenAiCompatibleTransport.class);
      var client=client(transport,primary(List.of(block("i1",false),block("i2",true)),List.of(task("i1","口算20题"))),reply);
      var result=client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
      assertTrue(result.needsReview()); assertEquals(1,result.assignments().size()); assertEquals("看不清",result.sourceDocument().blocks().getLast().text());
      assertTrue(result.sourceDocument().revisions().isEmpty());
      assertTrue(result.qualityFlags().stream().anyMatch(f->f.code().startsWith("REVIEW_")));
      verify(transport,times(2)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
      verify(transport,never()).complete(anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    }
  }
  @Test void lowRiskAndMissingOrOversizedOrInvalidRegionNeverTriggerVisualReview() throws Exception {
    for(List<Double> region:List.of(List.<Double>of(),List.of(.8,.8,.3,.3),List.of(0.,0.,1.,1.),List.of(0.,0.,0.,.5))) {
      var b=new java.util.LinkedHashMap<>(block("i2",true)); b.put("region",region);
      var transport=mock(OpenAiCompatibleTransport.class); var client=client(transport,primary(List.of(b),List.of()),"{}");
      var result=client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
      assertTrue(result.needsReview());
      verify(transport,times(1)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
    }
    var transport=mock(OpenAiCompatibleTransport.class); var client=client(transport,primary(List.of(block("i1",false)),List.of(task("i1","口算20题"))),"{}");
    assertFalse(client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow().needsReview());
    verify(transport,times(1)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
  @Test void knownTaskCannotBeReclassifiedAwayAndExistingDraftTaskIsNotDropped() throws Exception {
    var unclear=new java.util.LinkedHashMap<>(block("i2",true)); unclear.put("classification","TASK");
    var read=new java.util.LinkedHashMap<>(reading("数学订正5题","READABLE")); read.put("classification","NON_TASK");
    var transport=mock(OpenAiCompatibleTransport.class); var client=client(transport,primary(List.of(unclear),List.of(task("i2","订正5题"))),patch(read,List.of(),List.of()));
    var result=client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
    assertEquals(1,result.assignments().size()); assertTrue(result.needsReview()); assertEquals("TASK",result.sourceDocument().blocks().getFirst().classification());
  }
  @Test void emptyFirstDraftCanRecoverLocatedTaskAndDisableSwitchKeepsEvidenceForParent() throws Exception {
    String first=primary(List.of(block("i2",true)),List.of());
    String reply=patch(reading("数学订正5题","READABLE"),List.of(),List.of(Map.of("assignment",task("i2","订正5题"),"reason","局部识别出任务")));
    var transport=mock(OpenAiCompatibleTransport.class); var client=client(transport,first,reply);
    var result=client.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
    assertFalse(result.needsReview()); assertEquals(1,result.assignments().size());
    var off=mock(OpenAiCompatibleTransport.class); var disabled=client(off,first,reply); ReflectionTestUtils.setField(disabled,"visualReviewEnabled",false);
    var retained=disabled.organizeImage(new ConfigurableHomeworkOrganizerModelClientTest.TestStudent(),"图片",image(),"").orElseThrow();
    assertTrue(retained.needsReview()); assertTrue(retained.assignments().isEmpty());
    verify(off,times(1)).completeWithImage(anyString(),anyString(),anyString(),anyString(),anyInt(),anyString(),anyMap());
  }
}
