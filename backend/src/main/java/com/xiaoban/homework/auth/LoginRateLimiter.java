package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Duration;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;
import org.springframework.stereotype.Component;

/**
 * 登录失败限流：默认家长账号是全家共用的固定口令，口令写死在客户端里，
 * 服务端如果不做任何失败次数约束，接口就是一台无成本的口令爆破机。
 *
 * <p>按登录名做固定窗口计数（5 分钟内最多 5 次失败）。不按 IP 计数：家庭网络普遍是
 * NAT/移动网络，出口 IP 会变，按 IP 既拦不住同一设备换网络重试，也容易误伤同一出口下
 * 的多台设备。登录成功立即清空计数，正常启动/重登完全不受影响。
 *
 * <p>表是有界的：超过 {@link #MAX_TRACKED_KEYS} 个 key 时整表滚动淘汰过期窗口，
 * 达到上限后不再登记新 key（宁可放过，不把内存交给请求方控制）。
 */
@Component
public class LoginRateLimiter {
  static final int MAX_FAILED_ATTEMPTS = 5;
  static final Duration WINDOW = Duration.ofMinutes(5);
  static final int MAX_TRACKED_KEYS = 2048;

  private final Map<String, FailureWindow> failures = new ConcurrentHashMap<>();
  private final LongSupplier clock;

  public LoginRateLimiter() {
    this(System::currentTimeMillis);
  }

  /** 包可见：单测注入可控时钟，避免 sleep。 */
  LoginRateLimiter(LongSupplier clock) {
    this.clock = clock;
  }

  public static String key(String loginName) {
    return loginName == null ? "" : loginName.trim().toLowerCase();
  }

  /** 窗口内失败次数已达上限时直接拒绝，不再查库、也不再校验口令。 */
  public void check(String loginName) {
    String key = key(loginName);
    FailureWindow window = failures.get(key);
    if (window == null) return;
    long now = clock.getAsLong();
    if (now - window.startedAtEpochMs >= WINDOW.toMillis()) {
      failures.remove(key, window);
      return;
    }
    if (window.count >= MAX_FAILED_ATTEMPTS) {
      throw new ApiExceptions.TooManyRequests("登录失败次数过多，请 5 分钟后再试");
    }
  }

  public void recordFailure(String loginName) {
    String key = key(loginName);
    long now = clock.getAsLong();
    failures.compute(key, (ignored, current) -> {
      if (current == null || now - current.startedAtEpochMs >= WINDOW.toMillis()) {
        return new FailureWindow(now, 1);
      }
      return new FailureWindow(current.startedAtEpochMs, current.count + 1);
    });
    pruneIfNeeded(now);
  }

  public void clear(String loginName) {
    failures.remove(key(loginName));
  }

  private void pruneIfNeeded(long now) {
    if (failures.size() <= MAX_TRACKED_KEYS) return;
    Iterator<Map.Entry<String, FailureWindow>> iterator = failures.entrySet().iterator();
    while (iterator.hasNext()) {
      Map.Entry<String, FailureWindow> entry = iterator.next();
      if (now - entry.getValue().startedAtEpochMs >= WINDOW.toMillis()) iterator.remove();
    }
  }

  private static final class FailureWindow {
    final long startedAtEpochMs;
    final int count;

    FailureWindow(long startedAtEpochMs, int count) {
      this.startedAtEpochMs = startedAtEpochMs;
      this.count = count;
    }
  }
}
