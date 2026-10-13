package com.xiaoban.homework.family;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/family/parent-access")
public class FamilyParentAccessController {
  private final FamilyParentAccessService service;

  public FamilyParentAccessController(FamilyParentAccessService service) {
    this.service = service;
  }

  @GetMapping
  public FamilyParentAccessDtos.StatusResponse status(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId) {
    return service.status(familyId);
  }

  @PutMapping
  public FamilyParentAccessDtos.StatusResponse setCode(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @Valid @RequestBody FamilyParentAccessDtos.CodeRequest request) {
    return service.setCode(familyId, request);
  }

  @DeleteMapping
  public FamilyParentAccessDtos.StatusResponse clearCode(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId) {
    return service.clearCode(familyId);
  }

  @PostMapping("/verify")
  public FamilyParentAccessDtos.VerifyResponse verify(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @Valid @RequestBody FamilyParentAccessDtos.CodeRequest request) {
    return service.verify(familyId, request);
  }
}
