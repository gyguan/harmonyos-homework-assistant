package com.xiaoban.homework.auth;

import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
  private final AuthService service;
  private final AuthTokenService tokens;
  public AuthController(AuthService service, AuthTokenService tokens) { this.service = service; this.tokens = tokens; }

  @GetMapping("/family-accounts")
  public FamilyAccountDtos.Response familyAccounts(
      @RequestAttribute(AuthInterceptor.ACCOUNT_ID) UUID accountId,
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId) {
    return service.familyAccounts(familyId, accountId);
  }

  @PutMapping("/family-accounts/me")
  public FamilyAccountDtos.Item updateMyFamilyAccount(
      @RequestAttribute(AuthInterceptor.ACCOUNT_ID) UUID accountId,
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @Valid @RequestBody FamilyAccountDtos.UpdateMineRequest request) {
    return service.updateMyFamilyAccount(familyId, accountId, request);
  }

  @PostMapping("/family-accounts")
  public FamilyAccountDtos.Item createFamilyAccount(
      @RequestAttribute(AuthInterceptor.ACCOUNT_ID) UUID accountId,
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @Valid @RequestBody FamilyAccountDtos.CreateRequest request) {
    return service.createFamilyAccount(familyId, accountId, request);
  }

  @PostMapping("/login")
  public LoginResponse login(@Valid @RequestBody LoginRequest request) { return service.login(request); }

  @GetMapping("/session")
  public AuthService.SessionResponse session(@RequestAttribute(AuthInterceptor.ACCOUNT_ID) UUID accountId,
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId) {
    return service.session(accountId, familyId);
  }

  @PostMapping("/logout")
  public void logout(@RequestAttribute(AuthInterceptor.AUTH_TOKEN) String token) { tokens.revoke(token); }
}
