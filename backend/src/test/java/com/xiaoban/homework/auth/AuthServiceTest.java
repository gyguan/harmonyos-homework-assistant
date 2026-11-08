package com.xiaoban.homework.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

/** 限流必须发生在查库之前，否则失败请求一样能打满数据库。 */
class AuthServiceTest {
  private final AccountRepository accounts = mock(AccountRepository.class);
  private final PasswordEncoder encoder = mock(PasswordEncoder.class);
  private final AuthTokenService tokens = mock(AuthTokenService.class);
  private final AtomicLong now = new AtomicLong(1_000_000L);
  private final LoginRateLimiter limiter = new LoginRateLimiter(now::get);
  private final AuthService service = new AuthService(accounts, encoder, tokens, limiter);

  @Test
  void lockedAccountIsRejectedWithoutHittingDatabase() {
    when(accounts.findByLoginName("parent")).thenReturn(Optional.empty());
    for (int i = 0; i < LoginRateLimiter.MAX_FAILED_ATTEMPTS; i++) {
      assertThrows(ApiExceptions.Unauthorized.class,
          () -> service.login(new LoginRequest("parent", "wrong")));
    }
    assertThrows(ApiExceptions.TooManyRequests.class,
        () -> service.login(new LoginRequest("parent", "wrong")));
    verify(accounts, times(LoginRateLimiter.MAX_FAILED_ATTEMPTS)).findByLoginName("parent");
  }

  @Test
  void successfulLoginClearsFailedAttempts() {
    UUID accountId = UUID.randomUUID();
    UUID familyId = UUID.randomUUID();
    AccountEntity account = new AccountEntity(
        accountId, familyId, "parent", "hash", "家长", Instant.now());
    when(accounts.findByLoginName("parent")).thenReturn(Optional.of(account));
    when(encoder.matches(eq("parent123"), eq("hash"))).thenReturn(true);
    when(tokens.issue(accountId, familyId)).thenReturn("token-1");

    // 锁定期内正确口令也一样被拒（这正是限流的语义），所以只先输错 3 次（未达上限）。
    for (int i = 0; i < 3; i++) {
      assertThrows(ApiExceptions.Unauthorized.class,
          () -> service.login(new LoginRequest("parent", "wrong")));
    }
    LoginResponse response = service.login(new LoginRequest("parent", "parent123"));
    assertEquals("token-1", response.token());
    // 成功后计数清零：还能再完整输错 5 次才锁定，而不是接着前面的 3 次累计。
    for (int i = 0; i < LoginRateLimiter.MAX_FAILED_ATTEMPTS; i++) {
      assertThrows(ApiExceptions.Unauthorized.class,
          () -> service.login(new LoginRequest("parent", "wrong")));
    }
    assertThrows(ApiExceptions.TooManyRequests.class,
        () -> service.login(new LoginRequest("parent", "wrong")));
    verify(accounts, times(3 + 1 + LoginRateLimiter.MAX_FAILED_ATTEMPTS)).findByLoginName(any());
  }
}
