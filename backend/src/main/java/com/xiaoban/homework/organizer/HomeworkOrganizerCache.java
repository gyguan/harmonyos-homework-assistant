package com.xiaoban.homework.organizer;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Process-local private response cache. Keys are hashes; values never leave memory or enter logs.
 * Serialized values avoid sharing mutable DTO collections across requests. Both entry count and
 * UTF-8 payload bytes are bounded. No provider call runs under this cache's lock.
 */
@Component
final class HomeworkOrganizerCache {
  private record Entry(String json, int bytes, long expiresAt) {}
  private final LinkedHashMap<String, Entry> entries = new LinkedHashMap<>(16, .75f, true);
  private final boolean enabled;
  private final long ttlMillis;
  private final int maxEntries;
  private final long maxBytes;
  private final Clock clock;
  private long bytes;

  @Autowired
  HomeworkOrganizerCache(@Value("${app.organizer.cache.enabled:true}") boolean enabled,
      @Value("${app.organizer.cache.ttl-seconds:300}") long ttlSeconds,
      @Value("${app.organizer.cache.max-entries:128}") int maxEntries,
      @Value("${app.organizer.cache.max-bytes:8388608}") long maxBytes) {
    this(enabled, Duration.ofSeconds(Math.max(1, Math.min(900, ttlSeconds))),
        maxEntries, maxBytes, Clock.systemUTC());
  }

  HomeworkOrganizerCache(boolean enabled, Duration ttl, int maxEntries, long maxBytes, Clock clock) {
    this.enabled = enabled;
    this.ttlMillis = Math.max(1, Math.min(900_000, ttl.toMillis()));
    this.maxEntries = Math.max(1, Math.min(1024, maxEntries));
    this.maxBytes = Math.max(1, Math.min(32L * 1024 * 1024, maxBytes));
    this.clock = clock;
  }

  boolean enabled() { return enabled; }

  synchronized Optional<String> get(String key) {
    if (!enabled || key == null) return Optional.empty();
    evictExpired();
    var entry = entries.get(key);
    return entry == null ? Optional.empty() : Optional.of(entry.json());
  }

  synchronized void put(String key, String json) {
    if (!enabled || key == null || json == null) return;
    evictExpired();
    int size = json.getBytes(StandardCharsets.UTF_8).length;
    if (size > maxBytes) return;
    var old = entries.remove(key);
    if (old != null) bytes -= old.bytes();
    entries.put(key, new Entry(json, size, clock.millis() + ttlMillis));
    bytes += size;
    var iterator = entries.entrySet().iterator();
    while (entries.size() > maxEntries || bytes > maxBytes) {
      bytes -= iterator.next().getValue().bytes(); iterator.remove();
    }
  }

  // Expired private content is removed even when no further imports arrive.
  @Scheduled(fixedDelay = 60_000)
  synchronized void evictExpired() {
    var iterator = entries.values().iterator();
    while (iterator.hasNext()) {
      var entry = iterator.next();
      if (entry.expiresAt() <= clock.millis()) { bytes -= entry.bytes(); iterator.remove(); }
    }
  }
}
