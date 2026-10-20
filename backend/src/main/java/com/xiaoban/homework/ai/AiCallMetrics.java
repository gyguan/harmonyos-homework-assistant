package com.xiaoban.homework.ai;

import java.util.ArrayList;
import java.util.List;
import tools.jackson.databind.JsonNode;

/** Request-thread scoped, content-free observations. No state survives scope closure. */
public final class AiCallMetrics implements AutoCloseable {
  private static final ThreadLocal<AiCallMetrics> CURRENT = new ThreadLocal<>();
  private final AiCallMetrics previous;
  private final List<Call> calls = new ArrayList<>();
  public record Usage(Long tokensIn, Long tokensOut, Long cachedTokens, Long imageTokens) {
    public Usage(Long tokensIn, Long tokensOut, Long cachedTokens) { this(tokensIn,tokensOut,cachedTokens,null); }
  }
  public record Call(String stage, String model, long elapsedMs, boolean success, Usage usage, String provider, String promptVersion) {
    public Call(String stage, String model, long elapsedMs, boolean success, Usage usage, String provider) {
      this(stage, model, elapsedMs, success, usage, provider, "unavailable");
    }
    public Call(String stage, String model, long elapsedMs, boolean success, Usage usage) {
      this(stage, model, elapsedMs, success, usage, "unavailable");
    }
  }

  private AiCallMetrics() { previous = CURRENT.get(); CURRENT.set(this); }
  public static boolean active() { return CURRENT.get() != null; }
  public static AiCallMetrics open() { return new AiCallMetrics(); }
  public List<Call> calls() { return List.copyOf(calls); }
  public static void record(Call call) {
    var current = CURRENT.get();
    if (current != null) current.calls.add(call);
  }
  /** Hash actual caller instructions and schema, including review and dynamic experience context.
   * Map key order is canonical; no prompt/source content is retained by the observation.
   */
  public static String promptVersion(String instructions, String schemaName, java.util.Map<String, Object> schema) {
    if (!active()) return "unavailable";
    String value = tools.jackson.databind.json.JsonMapper.builder().build().writeValueAsString(
        java.util.Arrays.asList(instructions, schemaName, canonical(schema)));
    try {
      return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256")
          .digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
    } catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
  }
  private static Object canonical(Object value) {
    if (value instanceof java.util.Map<?, ?> map) {
      var ordered = new java.util.TreeMap<String, Object>();
      map.forEach((key, item) -> ordered.put(String.valueOf(key), canonical(item)));
      return ordered;
    }
    if (value instanceof java.util.List<?> items) return items.stream().map(AiCallMetrics::canonical).toList();
    return value;
  }
  public static Usage usage(JsonNode root) {
    var usage = root.path("usage");
    return new Usage(number(usage, "input_tokens", "prompt_tokens"),
        number(usage, "output_tokens", "completion_tokens"),
        number(usage.path("input_tokens_details"), "cached_tokens", "cached_tokens") != null
            ? number(usage.path("input_tokens_details"), "cached_tokens", "cached_tokens")
            : number(usage.path("prompt_tokens_details"), "cached_tokens", "cached_tokens"),
        number(usage.path("input_tokens_details"), "image_tokens", "image_tokens") != null
            ? number(usage.path("input_tokens_details"), "image_tokens", "image_tokens")
            : number(usage.path("prompt_tokens_details"), "image_tokens", "image_tokens"));
  }
  private static Long number(JsonNode node, String primary, String alternate) {
    var value = node.has(primary) ? node.path(primary) : node.path(alternate);
    return value.isIntegralNumber() && value.canConvertToLong() && value.asLong() >= 0
        ? value.asLong() : null;
  }
  @Override public void close() {
    if (previous == null) CURRENT.remove(); else CURRENT.set(previous);
  }
}
