package com.xiaoban.homework.toeic;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/toeic/vocabulary-recalls")
public class ToeicVocabularyRecallController {
  private final ToeicVocabularyRecallService service;

  public ToeicVocabularyRecallController(ToeicVocabularyRecallService service) {
    this.service = service;
  }

  @GetMapping
  public List<ToeicVocabularyRecallDtos.Response> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId) {
    return service.list(familyId, studentId);
  }

  @PutMapping("/{vocabularyId}")
  public ToeicVocabularyRecallDtos.Response upsert(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @PathVariable String vocabularyId,
      @Valid @RequestBody ToeicVocabularyRecallDtos.UpsertRequest input) {
    return service.upsert(familyId, studentId, vocabularyId, input);
  }
}
