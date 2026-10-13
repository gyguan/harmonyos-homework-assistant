package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
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

  public AuthService(AccountRepository accounts, PasswordEncoder passwordEncoder, AuthTokenService tokens) {
    this.accounts = accounts; this.passwordEncoder = passwordEncoder; this.tokens = tokens;
  }

  public FamilyAccountDtos.Response familyAccounts(UUID familyId, UUID accountId) {
    List<FamilyAccountDtos.Item> items = new ArrayList<>();
    for (AccountEntity account : accounts.findByFamilyIdOrderByCreatedAtAsc(familyId)) {
      items.add(new FamilyAccountDtos.Item(
          account.id.toString(), account.loginName, account.displayName, accountId.equals(account.id)));
    }
    return new FamilyAccountDtos.Response(List.copyOf(items));
  }

  public FamilyAccountDtos.Item updateMyFamilyAccount(
      UUID familyId, UUID accountId, FamilyAccountDtos.UpdateMineRequest request) {
    AccountEntity account = accounts.findById(accountId)
        .orElseThrow(() -> new ApiExceptions.Unauthorized("登录状态已失效，请重新登录"));
    if (!familyId.equals(account.familyId)) throw new ApiExceptions.Unauthorized("登录状态无效");
    account.displayName = request.displayName().trim();
    account.updatedAt = Instant.now();
    accounts.save(account);
    return new FamilyAccountDtos.Item(
        account.id.toString(), account.loginName, account.displayName, true);
  }

  public FamilyAccountDtos.Item createFamilyAccount(
      UUID familyId, UUID accountId, FamilyAccountDtos.CreateRequest request) {
    AccountEntity current = accounts.findById(accountId)
        .orElseThrow(() -> new ApiExceptions.Unauthorized("登录状态已失效，请重新登录"));
    if (!familyId.equals(current.familyId)) throw new ApiExceptions.Unauthorized("登录状态无效");

    String loginName = request.loginName().trim();
    String displayName = request.displayName().trim();
    if (accounts.findByLoginName(loginName).isPresent()) {
      throw new ApiExceptions.BadRequest("登录名已存在");
    }

    Instant now = Instant.now();
    AccountEntity created = new AccountEntity(
        UUID.randomUUID(), familyId, loginName, passwordEncoder.encode(request.password()), displayName, now);
    accounts.save(created);
    log.info("auth family_account_created familyId={} accountId={} createdAccountId={}",
        familyId, accountId, created.id);
    return new FamilyAccountDtos.Item(
        created.id.toString(), created.loginName, created.displayName, false);
  }

  public LoginResponse login(LoginRequest request) {
    AccountEntity account = accounts.findByLoginName(request.loginName()).orElse(null);
    if (account == null || !passwordEncoder.matches(request.password(), account.passwordHash)) {
      log.warn("auth login_failed reason=INVALID_CREDENTIALS");
      throw new ApiExceptions.Unauthorized("账号或密码错误");
    }
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
