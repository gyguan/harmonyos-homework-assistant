package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {
  private static final Logger log = LoggerFactory.getLogger(AuthService.class);
  private final AccountRepository accounts;
  private final PasswordEncoder passwordEncoder;
  private final AuthTokenService tokens;
  private final LoginRateLimiter rateLimiter;

  public AuthService(AccountRepository accounts, PasswordEncoder passwordEncoder,
      AuthTokenService tokens, LoginRateLimiter rateLimiter) {
    this.accounts = accounts; this.passwordEncoder = passwordEncoder; this.tokens = tokens;
    this.rateLimiter = rateLimiter;
  }

  public LoginResponse login(LoginRequest request) {
    rateLimiter.check(request.loginName());
    AccountEntity account = accounts.findByLoginName(request.loginName()).orElse(null);
    if (account == null || !passwordEncoder.matches(request.password(), account.passwordHash)) {
      rateLimiter.recordFailure(request.loginName());
      log.warn("auth login_failed reason=INVALID_CREDENTIALS");
      throw new ApiExceptions.Unauthorized("账号或密码错误");
    }
    rateLimiter.clear(request.loginName());
    String token = tokens.issue(account.id, account.familyId);
    log.info("auth login_success accountId={} familyId={}", account.id, account.familyId);
    return new LoginResponse(token, account.displayName, account.familyId.toString());
  }

  public SessionResponse session(UUID accountId, UUID familyId) {
    AccountEntity account = accounts.findById(accountId)
        .orElseThrow(() -> new ApiExceptions.Unauthorized("登录状态已失效，请重新登录"));
    if (!familyId.equals(account.familyId)) throw new ApiExceptions.Unauthorized("登录状态无效");
    return new SessionResponse(account.displayName);
  }

  public record SessionResponse(String displayName) {}
}
