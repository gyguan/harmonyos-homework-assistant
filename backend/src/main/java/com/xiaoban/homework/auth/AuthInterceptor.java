package com.xiaoban.homework.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class AuthInterceptor implements HandlerInterceptor {
  public static final String FAMILY_ID = "familyId";
  public static final String ACCOUNT_ID = "accountId";
  public static final String AUTH_TOKEN = "authToken";
  private final AuthTokenService tokens;
  public AuthInterceptor(AuthTokenService tokens) { this.tokens = tokens; }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    String header = request.getHeader("Authorization");
    String token = header != null && header.startsWith("Bearer ") ? header.substring(7) : null;
    AuthTokenService.SessionInfo session = tokens.requireSession(token);
    request.setAttribute(FAMILY_ID, session.familyId());
    request.setAttribute(ACCOUNT_ID, session.accountId());
    request.setAttribute(AUTH_TOKEN, token);
    return true;
  }
}
