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
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class AccessLogFilter extends OncePerRequestFilter {
  private static final Logger log = LoggerFactory.getLogger(AccessLogFilter.class);
  static final String ATTR_REQUEST_ID = AccessLogFilter.class.getName() + ".requestId";
  static final String ATTR_CLIENT_SCENE = AccessLogFilter.class.getName() + ".clientScene";
  private static final String REQUEST_ID_HEADER = "X-Request-Id";
  private static final String CLIENT_SCENE_HEADER = "X-Client-Scene";
  private static final String CLIENT_REQUEST_KEY_HEADER = "X-Client-Request-Key";
  private static final long DUPLICATE_WINDOW_MS = 1500L;
  private static final long RECENT_RETENTION_MS = 60000L;
  private static final int MAX_RECENT_KEYS = 2048;
  private volatile Map<String, Long> recentRequests = new ConcurrentHashMap<>();
  private final AtomicLong windowStartedAt = new AtomicLong(0L);
  private final AtomicBoolean rollingWindow = new AtomicBoolean(false);
  private final HttpLogProperties httpLogProperties;

  public AccessLogFilter(HttpLogProperties httpLogProperties) {
    this.httpLogProperties = httpLogProperties;
  }

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
    request.setAttribute(ATTR_REQUEST_ID, requestId);
    request.setAttribute(ATTR_CLIENT_SCENE, scene);
    response.setHeader(REQUEST_ID_HEADER, requestId);
    MDC.put("requestId", requestId);
    MDC.put("scene", scene);
    if (httpLogProperties.isLogPayloads()) {
      log.info("[HTTP-REQUEST] requestId={} scene={} {} {} query={} contentType={} contentLength={}",
          requestId, scene, request.getMethod(), sanitize(request.getRequestURI()),
          payloadText(request.getQueryString()), sanitize(request.getContentType()), request.getContentLengthLong());
    }
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
      MDC.remove("requestId");
      MDC.remove("scene");
    }
  }

  boolean isDuplicate(String client, String requestKey, long nowMs) {
    if (requestKey == null || requestKey.isBlank()) return false;
    String boundedKey = requestKey.length() > 512 ? requestKey.substring(0, 512) : requestKey;
    String key = client + "|" + boundedKey;
    rollWindow(nowMs);
    Map<String, Long> current = recentRequests;
    // 硬上限：客户端可以随意编造 requestKey，且 /health 也经过这个过滤器。
    // 达到上限后不再登记新 key，只对已登记的 key 做重复判断，避免无凭据打爆内存。
    Long previous = current.size() >= MAX_RECENT_KEYS ? current.get(key) : current.put(key, nowMs);
    return previous != null && nowMs - previous >= 0 && nowMs - previous <= DUPLICATE_WINDOW_MS;
  }

  /**
   * 按固定窗口整表滚动，O(1)，不再每请求全表扫描。
   * 原来的 removeIf 只能淘汰「满 60 秒」的条目，攻击者不断变化 requestKey 时一条也删不掉，
   * 反而让去重表无限增长。丢弃整个窗口只影响边界处 1.5 秒的重复判定，可接受。
   */
  private void rollWindow(long nowMs) {
    long started = windowStartedAt.get();
    if (started == 0L) {
      windowStartedAt.compareAndSet(0L, nowMs);
      return;
    }
    if (nowMs - started < RECENT_RETENTION_MS) return;
    if (!rollingWindow.compareAndSet(false, true)) return;
    try {
      if (windowStartedAt.compareAndSet(started, nowMs)) {
        recentRequests = new ConcurrentHashMap<>();
      }
    } finally {
      rollingWindow.set(false);
    }
  }

  String safeHeader(String value, int maxLength) {
    if (value == null || value.isBlank()) return "-";
    String sanitized = sanitize(value).replaceAll("[^A-Za-z0-9._:-]", "_");
    if (sanitized.length() > maxLength) sanitized = sanitized.substring(0, maxLength);
    return sanitized;
  }

  private String payloadText(String value) {
    if (value == null || value.isBlank()) return "-";
    String compact = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    int max = httpLogProperties.getMaxPayloadChars();
    return compact.length() <= max ? compact : compact.substring(0, max) + "...";
  }

  private String sanitize(String value) {
    if (value == null) return "-";
    return value.replace('\r', '_').replace('\n', '_');
  }
}
