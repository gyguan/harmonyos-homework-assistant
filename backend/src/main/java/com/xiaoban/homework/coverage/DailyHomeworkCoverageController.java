package com.xiaoban.homework.coverage;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework-coverage")
public class DailyHomeworkCoverageController {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private final DailyHomeworkCoverageService service;

  public DailyHomeworkCoverageController(DailyHomeworkCoverageService service) {
    this.service = service;
  }

  @GetMapping
  public DailyHomeworkCoverageDtos.Response get(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @RequestParam String parentIdentity,
      @RequestParam(required = false) LocalDate taskDate) {
    LocalDate date = taskDate == null ? LocalDate.now(BUSINESS_ZONE) : taskDate;
    return service.get(familyId, parentIdentity, studentId, date);
  }

  @PutMapping("/{taskDate}/me")
  public DailyHomeworkCoverageDtos.Response updateMine(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @RequestAttribute(AuthInterceptor.ACCOUNT_ID) UUID accountId,
      @PathVariable String studentId,
      @PathVariable LocalDate taskDate,
      @Valid @RequestBody DailyHomeworkCoverageDtos.UpdateRequest input) {
    return service.updateMine(familyId, accountId, studentId, taskDate, input);
  }
}
