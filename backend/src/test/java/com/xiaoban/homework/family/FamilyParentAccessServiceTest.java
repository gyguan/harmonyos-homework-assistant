package com.xiaoban.homework.family;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class FamilyParentAccessServiceTest {

  @Test
  void statusIsDisabledWhenFamilyHasNoCode() {
    var families = mock(FamilyRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var service = new FamilyParentAccessService(families, encoder);
    UUID familyId = UUID.randomUUID();
    FamilyEntity family = new FamilyEntity(familyId, "我的家庭", Instant.now());
    when(families.findById(familyId)).thenReturn(Optional.of(family));

    assertFalse(service.status(familyId).enabled());
  }

  @Test
  void setCodeStoresOnlyEncodedValue() {
    var families = mock(FamilyRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var service = new FamilyParentAccessService(families, encoder);
    UUID familyId = UUID.randomUUID();
    FamilyEntity family = new FamilyEntity(familyId, "我的家庭", Instant.now());
    when(families.lockById(familyId)).thenReturn(Optional.of(family));
    when(encoder.encode("1234")).thenReturn("$2a$encoded-parent-access");

    var result = service.setCode(
        familyId, new FamilyParentAccessDtos.CodeRequest("1234"));

    assertTrue(result.enabled());
    assertEquals("$2a$encoded-parent-access", family.parentAccessCodeHash);
    assertFalse("1234".equals(family.parentAccessCodeHash));
    verify(families).save(family);
  }

  @Test
  void verifyUsesPasswordEncoderAgainstStoredHash() {
    var families = mock(FamilyRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var service = new FamilyParentAccessService(families, encoder);
    UUID familyId = UUID.randomUUID();
    FamilyEntity family = new FamilyEntity(familyId, "我的家庭", Instant.now());
    family.parentAccessCodeHash = "$2a$encoded-parent-access";
    when(families.findById(familyId)).thenReturn(Optional.of(family));
    when(encoder.matches("1234", "$2a$encoded-parent-access")).thenReturn(true);

    var result = service.verify(
        familyId, new FamilyParentAccessDtos.CodeRequest("1234"));

    assertTrue(result.valid());
    verify(encoder).matches("1234", "$2a$encoded-parent-access");
  }

  @Test
  void clearCodeRemovesCloudProtection() {
    var families = mock(FamilyRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var service = new FamilyParentAccessService(families, encoder);
    UUID familyId = UUID.randomUUID();
    FamilyEntity family = new FamilyEntity(familyId, "我的家庭", Instant.now());
    family.parentAccessCodeHash = "$2a$encoded-parent-access";
    when(families.lockById(familyId)).thenReturn(Optional.of(family));

    var result = service.clearCode(familyId);

    assertFalse(result.enabled());
    assertNull(family.parentAccessCodeHash);
    verify(families).save(family);
  }
}
