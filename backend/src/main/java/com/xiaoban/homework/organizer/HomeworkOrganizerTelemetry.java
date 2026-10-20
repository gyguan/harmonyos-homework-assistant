package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.AiCallMetrics;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import tools.jackson.databind.json.JsonMapper;

/** One measurement per attempt, including rejected/failed requests; never includes source content. */
final class HomeworkOrganizerTelemetry implements AutoCloseable {
  private static final ThreadLocal<HomeworkOrganizerTelemetry> CURRENT = new ThreadLocal<>();
  private static final JsonMapper JSON = JsonMapper.builder().build();
  private final HomeworkOrganizerTelemetry previous;
  private final AiCallMetrics ai = AiCallMetrics.open();
  private final long started = System.nanoTime();
  private final Map<String, Object> data = new LinkedHashMap<>();
  private final Map<String, Long> stages = new LinkedHashMap<>();
  private final Set<String> flags = new LinkedHashSet<>();

  private HomeworkOrganizerTelemetry(String importId, String kind) {
    previous = CURRENT.get(); CURRENT.set(this);
    data.put("schemaVersion", 1);
    data.put("requestId", safeId(MDC.get("requestId")));
    data.put("importId", safeId(importId));
    data.put("inputType", kind);
    data.put("promptVersion", "unavailable");
    data.put("ruleVersion", "unavailable");
    data.put("experienceVersion", "unavailable");
    data.put("provider", "unavailable");
    data.put("model", "unavailable");
    data.put("success", false);
    data.put("taskCount", 0);
    data.put("cacheHit", false);
    data.put("reviewTriggered", false);
    data.put("reviewReason", "NONE");
  }
  static HomeworkOrganizerTelemetry open(String importId, String kind) {
    return new HomeworkOrganizerTelemetry(importId, kind);
  }
  static void versions(String model, String provider, String prompt, String rules, String experience) {
    var t = CURRENT.get();
    if (t == null) return;
    t.data.put("model", safeId(model));
    t.data.put("provider", safeId(provider));
    t.data.put("promptVersion", fingerprint(prompt));
    t.data.put("ruleVersion", fingerprint(rules));
    t.data.put("experienceVersion", fingerprint(experience));
  }
  static void stage(String name, long start) {
    var t = CURRENT.get();
    if (t != null) t.stages.merge(name, TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start), Long::sum);
  }
  static void quality(String risk, java.util.List<HomeworkOrganizerDtos.QualityFlag> flags, String reviewOutcome) {
    var t = CURRENT.get();
    if (t == null) return;
    t.data.put("riskLevel", risk);
    t.data.put("finalQualityFlags", flags.stream().map(HomeworkOrganizerDtos.QualityFlag::code).distinct().toList());
    t.data.put("reviewOutcome", reviewOutcome);
  }
  static void experiences(HomeworkOrganizerDtos.ExperienceUsage usage) {
    var t = CURRENT.get();
    if (t == null) return;
    t.data.put("retrievedExperienceIds", usage.retrievedExperienceIds());
    t.data.put("appliedExperienceIds", usage.appliedExperienceIds());
  }
  static void cacheHit(String provider) {
    var t = CURRENT.get();
    if (t != null) {
      t.data.put("cacheHit", true);
      if (provider != null) t.data.put("provider", safeId(provider));
      t.data.put("reviewOutcome", "CACHE_HIT");
    }
  }
  static void image(HomeworkImageInput.Prepared image) {
    var t = CURRENT.get();
    if (t != null) t.data.put("imagePreparation", Map.of("version", HomeworkImageInput.PROCESSING_VERSION,
        "width", image.width(), "height", image.height(), "outputWidth", image.outputWidth(),
        "outputHeight", image.outputHeight(), "orientation", image.orientation(),
        "inputBytes", image.inputBytes(), "outputBytes", image.outputBytes(), "orientationStatus", image.orientationStatus()));
  }
  static void imageOrientationUncertain(java.util.List<HomeworkOrganizerDtos.QualityFlag> flags) {
    var t = CURRENT.get();
    if (t == null) return;
    flag("IMAGE_ORIENTATION_UNCERTAIN");
    if (!"HIGH".equals(t.data.get("riskLevel"))) t.data.put("riskLevel", "MEDIUM");
    t.data.put("finalQualityFlags", flags.stream().map(HomeworkOrganizerDtos.QualityFlag::code).distinct().toList());
  }
  static void visualCrop(HomeworkImageCrop.Crop crop) {
    var t = CURRENT.get();
    if (t != null) t.data.put("visualReview", Map.of("kind", "REGION_CROP", "width", crop.width(),
        "height", crop.height(), "bytes", crop.bytes()));
  }
  static void flag(String code) { var t = CURRENT.get(); if (t != null) t.flags.add(code); }
  static void review(String reason) {
    var t = CURRENT.get();
    if (t != null) { t.data.put("reviewTriggered", true); t.data.put("reviewReason", reason); }
  }
  void success(int count) { data.put("success", true); data.put("taskCount", count); }
  Map<String, Object> measurement() {
    var calls = ai.calls();
    if (!calls.isEmpty() && !"unavailable".equals(calls.getFirst().provider()))
      data.put("provider", calls.getFirst().provider());
    data.put("elapsedMs", TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started));
    data.put("stage", "TOTAL");
    stages.put("model", calls.stream().filter(c -> "PRIMARY".equals(c.stage())).mapToLong(AiCallMetrics.Call::elapsedMs).sum());
    stages.put("reviewModel", calls.stream().filter(c -> "REVIEW".equals(c.stage())).mapToLong(AiCallMetrics.Call::elapsedMs).sum());
    data.put("stagesMs", Map.copyOf(stages));
    data.put("qualityFlags", Set.copyOf(flags));
    data.put("aiCalls", calls);
    data.put("callCount", calls.size());
    data.put("tokensIn", calls.isEmpty() && !Boolean.TRUE.equals(data.get("cacheHit")) || calls.stream().anyMatch(c -> c.usage().tokensIn() == null)
        ? "unavailable" : calls.stream().mapToLong(c -> c.usage().tokensIn()).sum());
    data.put("tokensOut", calls.isEmpty() && !Boolean.TRUE.equals(data.get("cacheHit")) || calls.stream().anyMatch(c -> c.usage().tokensOut() == null)
        ? "unavailable" : calls.stream().mapToLong(c -> c.usage().tokensOut()).sum());
    data.put("cachedTokensIn", tokenDetail(calls, false));
    data.put("imageTokensIn", tokenDetail(calls, true));
    return Map.copyOf(data);
  }
  private Object tokenDetail(java.util.List<AiCallMetrics.Call> calls, boolean image) {
    if (calls.isEmpty()) return Boolean.TRUE.equals(data.get("cacheHit")) ? 0L : "unavailable";
    var values = calls.stream().map(c -> image ? c.usage().imageTokens() : c.usage().cachedTokens()).toList();
    return values.stream().anyMatch(java.util.Objects::isNull) ? "unavailable" : values.stream().mapToLong(Long::longValue).sum();
  }
  static String fingerprint(String value) {
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
          .digest((value == null ? "" : value).getBytes(StandardCharsets.UTF_8)));
    } catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
  }
  private static String safeId(String value) {
    return value != null && value.matches("[A-Za-z0-9_.:/-]{1,160}") ? value : "unavailable";
  }
  @Override public void close() {
    try {
      LoggerFactory.getLogger(HomeworkOrganizerTelemetry.class).info(
          "homework_import measurement data={}", JSON.writeValueAsString(measurement()));
    } finally {
      ai.close();
      if (previous == null) CURRENT.remove(); else CURRENT.set(previous);
    }
  }
}
