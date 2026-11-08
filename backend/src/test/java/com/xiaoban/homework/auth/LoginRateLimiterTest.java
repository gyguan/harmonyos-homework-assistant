package com.xiaoban.homework.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.xiaoban.homework.common.ApiExceptions;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

class LoginRateLimiterTest {
  private final AtomicLong now = new AtomicLong(1_000_000L);

  @Test
  void blocksAfterFiveFailuresWithinWindow() {
    LoginRateLimiter limiter = new LoginRateLimiter(now::get);
    for (int i = 0; i < LoginRateLimiter.MAX_FAILED_ATTEMPTS; i++) {
      assertDoesNotThrow(() -> limiter.check("parent"));
      limiter.recordFailure("parent");
    }
    assertThrows(ApiExceptions.TooManyRequests.class, () -> limiter.check("parent"));
  }

  @Test
  void windowExpiryResetsCounter() {
    LoginRateLimiter limiter = new LoginRateLimiter(now::get);
    for (int i = 0; i < LoginRateLimiter.MAX_FAILED_ATTEMPTS; i++) limiter.recordFailure("parent");
    assertThrows(ApiExceptions.TooManyRequests.class, () -> limiter.check("parent"));
    now.addAndGet(LoginRateLimiter.WINDOW.toMillis() + 1);
    assertDoesNotThrow(() -> limiter.check("parent"));
    limiter.recordFailure("parent");
    assertDoesNotThrow(() -> limiter.check("parent"));
  }

  @Test
  void successfulLoginClearsCounterAndKeyIsNormalized() {
    LoginRateLimiter limiter = new LoginRateLimiter(now::get);
    for (int i = 0; i < LoginRateLimiter.MAX_FAILED_ATTEMPTS; i++) limiter.recordFailure("PARENT");
    assertThrows(ApiExceptions.TooManyRequests.class, () -> limiter.check(" parent "));
    limiter.clear("Parent");
    assertDoesNotThrow(() -> limiter.check("parent"));
    assertEquals("", LoginRateLimiter.key(null));
  }
}
