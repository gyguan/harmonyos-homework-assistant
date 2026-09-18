package com.xiaoban.homework.common;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class AccessLogFilter extends OncePerRequestFilter {
  private static final Logger log = LoggerFactory.getLogger(AccessLogFilter.class);
  private static final String REQUEST_ID_HEADER = "X-Request-Id";
  private static final String CLIENT_SCENE_HEADER = "X-Client-Scene";
  private static final String CLIENT_REQUEST_KEY_HEADER = "X-Client-Request-Key";
  private static final long DUPLICATE_WINDOW_MS = 1500L;
  private static final long RECENT_RETENTION_MS = 60000L;
  private static final int MAX_RECENT_KEYS = 2048;
  private final Map<String, Long> recentRequests = new ConcurrentHashMap<>();

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
      throws ServletException, IOException {
    long startedAt = System.nanoTime();
    long startedAtEpochMs = System.currentTimeMillis();
    String requestId = safeHeader(request.getHeader(REQUEST_ID_HEADER), 100);
    if ("-".equals(requestId)) requestId = UUID.randomUUID().toString();
    String scene = safeHeader(request.getHeader(CLIENT_SCENE_HEADER), 80);
    String requestKey = request.getHeader(CLIENT_REQUEST_KEY_HEADER);
    boolean duplicate = isDuplicate(sanitize(request.getRemoteAddr()), requestKey, startedAtEpochMs);
    response.setHeader(REQUEST_ID_HEADER, requestId);
    try {
      filterChain.doFilter(request, response);
    } finally {
      long elapsedMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt);
      log.info("[HTTP] requestId={} scene={} {} {} -> {} {}ms client={}",
          requestId,
          scene,
          request.getMethod(),
          sanitize(request.getRequestURI()),
          response.getStatus(),
          elapsedMs,
          sanitize(request.getRemoteAddr()));
      if (duplicate) {
        log.warn("[HTTP-DUPLICATE] requestId={} scene={} {} {} within={}ms",
            requestId, scene, request.getMethod(), sanitize(request.getRequestURI()), DUPLICATE_WINDOW_MS);
      }
    }
  }

  boolean isDuplicate(String client, String requestKey, long nowMs) {
    if (requestKey == null || requestKey.isBlank()) return false;
    String boundedKey = requestKey.length() > 512 ? requestKey.substring(0, 512) : requestKey;
    String key = client + "|" + boundedKey;
    Long previous = recentRequests.put(key, nowMs);
    if (recentRequests.size() > MAX_RECENT_KEYS) cleanupRecent(nowMs);
    return previous != null && nowMs - previous >= 0 && nowMs - previous <= DUPLICATE_WINDOW_MS;
  }

  private void cleanupRecent(long nowMs) {
    recentRequests.entrySet().removeIf(entry -> nowMs - entry.getValue() > RECENT_RETENTION_MS);
  }

  String safeHeader(String value, int maxLength) {
    if (value == null || value.isBlank()) return "-";
    String sanitized = sanitize(value).replaceAll("[^A-Za-z0-9._:-]", "_");
    if (sanitized.length() > maxLength) sanitized = sanitized.substring(0, maxLength);
    return sanitized;
  }

  private String sanitize(String value) {
    if (value == null) return "-";
    return value.replace('\r', '_').replace('\n', '_');
  }
}
