package com.xiaoban.homework.family;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FamilyParentAccessService {
  private static final Logger log = LoggerFactory.getLogger(FamilyParentAccessService.class);
  private final FamilyRepository families;
  private final PasswordEncoder encoder;

  public FamilyParentAccessService(FamilyRepository families, PasswordEncoder encoder) {
    this.families = families;
    this.encoder = encoder;
  }

  @Transactional(readOnly = true)
  public FamilyParentAccessDtos.StatusResponse status(UUID familyId) {
    FamilyEntity family = requireFamily(familyId);
    return new FamilyParentAccessDtos.StatusResponse(hasCode(family));
  }

  @Transactional
  public FamilyParentAccessDtos.StatusResponse setCode(
      UUID familyId, FamilyParentAccessDtos.CodeRequest request) {
    FamilyEntity family = families.lockById(familyId)
        .orElseThrow(() -> new ApiExceptions.NotFound("家庭不存在"));
    family.parentAccessCodeHash = encoder.encode(request.code());
    family.updatedAt = Instant.now();
    families.save(family);
    log.info("family parent_access_code_updated familyId={}", familyId);
    return new FamilyParentAccessDtos.StatusResponse(true);
  }

  @Transactional
  public FamilyParentAccessDtos.StatusResponse clearCode(UUID familyId) {
    FamilyEntity family = families.lockById(familyId)
        .orElseThrow(() -> new ApiExceptions.NotFound("家庭不存在"));
    family.parentAccessCodeHash = null;
    family.updatedAt = Instant.now();
    families.save(family);
    log.info("family parent_access_code_disabled familyId={}", familyId);
    return new FamilyParentAccessDtos.StatusResponse(false);
  }

  @Transactional(readOnly = true)
  public FamilyParentAccessDtos.VerifyResponse verify(
      UUID familyId, FamilyParentAccessDtos.CodeRequest request) {
    FamilyEntity family = requireFamily(familyId);
    boolean valid = hasCode(family) && encoder.matches(request.code(), family.parentAccessCodeHash);
    if (!valid) log.warn("family parent_access_code_verify_failed familyId={}", familyId);
    return new FamilyParentAccessDtos.VerifyResponse(valid);
  }

  private FamilyEntity requireFamily(UUID familyId) {
    return families.findById(familyId)
        .orElseThrow(() -> new ApiExceptions.NotFound("家庭不存在"));
  }

  private boolean hasCode(FamilyEntity family) {
    return family.parentAccessCodeHash != null && !family.parentAccessCodeHash.isBlank();
  }
}
