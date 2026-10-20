package com.xiaoban.homework.ai;

import java.util.ArrayList;
import java.util.List;
import tools.jackson.databind.JsonNode;

/** Request-thread scoped, content-free observations. No state survives scope closure. */
public final class AiCallMetrics implements AutoCloseable {
  private static final ThreadLocal<AiCallMetrics> CURRENT = new ThreadLocal<>();
  private final AiCallMetrics previous;
  private final List<Call> calls = new ArrayList<>();
  public record Usage(Long tokensIn, Long tokensOut, Long cachedTokens) {}
  public record Call(String stage, String model, long elapsedMs, boolean success, Usage usage) {}

  private AiCallMetrics() { previous = CURRENT.get(); CURRENT.set(this); }
  public static boolean active() { return CURRENT.get() != null; }
  public static AiCallMetrics open() { return new AiCallMetrics(); }
  public List<Call> calls() { return List.copyOf(calls); }
  public static void record(Call call) {
    var current = CURRENT.get();
    if (current != null) current.calls.add(call);
  }
  public static Usage usage(JsonNode root) {
    var usage = root.path("usage");
    return new Usage(number(usage, "input_tokens", "prompt_tokens"),
        number(usage, "output_tokens", "completion_tokens"),
        number(usage.path("input_tokens_details"), "cached_tokens", "cached_tokens") != null
            ? number(usage.path("input_tokens_details"), "cached_tokens", "cached_tokens")
            : number(usage.path("prompt_tokens_details"), "cached_tokens", "cached_tokens"));
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
