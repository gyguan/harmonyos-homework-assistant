package com.xiaoban.homework.practice;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PracticeController {
  private final PracticeContentService content;
  private final PracticeAttemptService attempts;

  public PracticeController(PracticeContentService content, PracticeAttemptService attempts) {
    this.content = content;
    this.attempts = attempts;
  }

  @GetMapping("/practice/papers/{paperId}")
  public PracticeDtos.PaperResponse paper(@PathVariable String paperId, @RequestParam int version) {
    return content.response(content.requirePaper(paperId, version));
  }

  @PostMapping("/students/{studentId}/practice/attempts")
  public PracticeDtos.AttemptResponse start(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestBody PracticeDtos.StartRequest input) {
    return attempts.start(familyId, studentId, input);
  }

  @GetMapping("/students/{studentId}/practice/attempts")
  public List<PracticeDtos.AttemptSummary> history(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @RequestParam(required = false) String paperId) {
    return attempts.history(familyId, studentId, paperId);
  }

  @PostMapping("/practice/attempts/{attemptId}/repeat")
  public PracticeDtos.AttemptResponse repeat(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID attemptId) {
    return attempts.repeat(familyId, attemptId);
  }

  @GetMapping("/practice/attempts/{attemptId}")
  public PracticeDtos.AttemptResponse attempt(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID attemptId) {
    return attempts.get(familyId, attemptId);
  }

  @PutMapping("/practice/attempts/{attemptId}/answers/{questionId}")
  public PracticeDtos.AnswerResponse answer(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID attemptId,
      @PathVariable String questionId,
      @Valid @RequestBody PracticeDtos.AnswerRequest input) {
    return attempts.saveAnswer(familyId, attemptId, questionId, input);
  }

  @PostMapping("/practice/attempts/{attemptId}/submit")
  public PracticeDtos.ResultResponse submit(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID attemptId) {
    return attempts.submit(familyId, attemptId);
  }

  @GetMapping("/practice/attempts/{attemptId}/result")
  public PracticeDtos.ResultResponse result(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID attemptId) {
    return attempts.result(familyId, attemptId);
  }
}
