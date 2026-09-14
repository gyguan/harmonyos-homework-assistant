package com.xiaoban.homework.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class AuthInterceptor implements HandlerInterceptor {
  public static final String FAMILY_ID = "familyId";
  private final AuthTokenService tokens;
  public AuthInterceptor(AuthTokenService tokens) { this.tokens = tokens; }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    String header = request.getHeader("Authorization");
    String token = header != null && header.startsWith("Bearer ") ? header.substring(7) : null;
    request.setAttribute(FAMILY_ID, tokens.requireFamily(token));
    return true;
  }
}
