package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {
  private final AccountRepository accounts;
  private final PasswordEncoder passwordEncoder;
  private final AuthTokenService tokens;

  public AuthService(AccountRepository accounts, PasswordEncoder passwordEncoder, AuthTokenService tokens) {
    this.accounts = accounts; this.passwordEncoder = passwordEncoder; this.tokens = tokens;
  }

  public LoginResponse login(LoginRequest request) {
    AccountEntity account = accounts.findByLoginName(request.loginName())
        .orElseThrow(() -> new ApiExceptions.Unauthorized("账号或密码错误"));
    if (!passwordEncoder.matches(request.password(), account.passwordHash)) {
      throw new ApiExceptions.Unauthorized("账号或密码错误");
    }
    return new LoginResponse(tokens.issue(account.familyId), account.displayName, account.familyId.toString());
  }
}
