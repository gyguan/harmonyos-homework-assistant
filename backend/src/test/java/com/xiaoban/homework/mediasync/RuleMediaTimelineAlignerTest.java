package com.xiaoban.homework.mediasync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class RuleMediaTimelineAlignerTest {
  private final RuleMediaTimelineAligner aligner = new RuleMediaTimelineAligner();

  @Test
  void explicitImageMarkersCreateTimelineWithoutLlm() {
    AudioTranscriptionClient.Transcript transcript = new AudioTranscriptionClient.Transcript(
        "asr-model",
        30000,
        List.of(
            new AudioTranscriptionClient.Segment(0, 0, 5000, "先看第一张图片"),
            new AudioTranscriptionClient.Segment(1, 5000, 12000, "这是第一部分"),
            new AudioTranscriptionClient.Segment(2, 12000, 18000, "现在看第二张"),
            new AudioTranscriptionClient.Segment(3, 18000, 30000, "继续完成练习")));
    RuleMediaTimelineAligner.Result result =
        aligner.align(transcript, List.of("img-1", "img-2")).orElseThrow();

    assertEquals(2, result.boundaries().size());
    assertEquals(0, result.boundaries().get(0).startMs());
    assertEquals(12000, result.boundaries().get(0).endMs());
    assertEquals(12000, result.boundaries().get(1).startMs());
    assertEquals(30000, result.boundaries().get(1).endMs());
  }

  @Test
  void previousPageInstructionFallsBackToSemanticAlignment() {
    AudioTranscriptionClient.Transcript transcript = new AudioTranscriptionClient.Transcript(
        "asr-model",
        20000,
        List.of(
            new AudioTranscriptionClient.Segment(0, 0, 8000, "看第一张"),
            new AudioTranscriptionClient.Segment(1, 8000, 12000, "下一张"),
            new AudioTranscriptionClient.Segment(2, 12000, 20000, "回到上一张")));
    assertTrue(aligner.align(transcript, List.of("img-1", "img-2")).isEmpty());
  }
}
