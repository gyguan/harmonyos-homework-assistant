package com.xiaoban.homework.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

class AuthServiceFamilyAccountTest {

  @Test
  void createsAnotherAccountInSameFamilyWithoutRole() {
    var accounts = mock(AccountRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var tokens = mock(AuthTokenService.class);
    var service = new AuthService(accounts, encoder, tokens);

    UUID familyId = UUID.randomUUID();
    UUID currentId = UUID.randomUUID();
    AccountEntity current = new AccountEntity(
        currentId, familyId, "parent", "hash", "爸爸", Instant.now());
    when(accounts.findById(currentId)).thenReturn(Optional.of(current));
    when(accounts.findByLoginName("mom")).thenReturn(Optional.empty());
    when(encoder.encode("secret12")).thenReturn("encoded");

    var created = service.createFamilyAccount(
        familyId, currentId,
        new FamilyAccountDtos.CreateRequest(" mom ", "secret12", " 妈妈 "));

    ArgumentCaptor<AccountEntity> captor = ArgumentCaptor.forClass(AccountEntity.class);
    verify(accounts).save(captor.capture());
    AccountEntity saved = captor.getValue();
    assertEquals(familyId, saved.familyId);
    assertEquals("mom", saved.loginName);
    assertEquals("妈妈", saved.displayName);
    assertEquals("encoded", saved.passwordHash);
    assertFalse(created.mine());
  }

  @Test
  void familyAccountListMarksCurrentAccountOnly() {
    var accounts = mock(AccountRepository.class);
    var encoder = mock(PasswordEncoder.class);
    var tokens = mock(AuthTokenService.class);
    var service = new AuthService(accounts, encoder, tokens);

    UUID familyId = UUID.randomUUID();
    UUID dadId = UUID.randomUUID();
    UUID momId = UUID.randomUUID();
    AccountEntity dad = new AccountEntity(dadId, familyId, "dad", "hash", "爸爸", Instant.now());
    AccountEntity mom = new AccountEntity(momId, familyId, "mom", "hash", "妈妈", Instant.now());
    when(accounts.findByFamilyIdOrderByCreatedAtAsc(familyId)).thenReturn(List.of(dad, mom));

    var response = service.familyAccounts(familyId, momId);

    assertEquals(2, response.accounts().size());
    assertFalse(response.accounts().getFirst().mine());
    assertTrue(response.accounts().get(1).mine());
    assertEquals("妈妈", response.accounts().get(1).displayName());
  }
}
