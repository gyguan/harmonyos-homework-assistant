package com.xiaoban.homework.ai;

import java.util.List;

/**
 * Provider capability contract used by model-facing clients.
 *
 * <p>Business code must choose output behavior from this contract rather than branching on
 * provider or model names.
 */
public record AiProviderCapabilities(
    Provider provider,
    ApiProtocol preferredProtocol,
    List<StructuredOutputMode> chatCompletionsModes,
    List<StructuredOutputMode> responsesModes) {

  public enum Provider {
    OPENAI,
    DEEPSEEK,
    ZHIPU_GLM,
    GENERIC_OPENAI_COMPATIBLE
  }

  public enum ApiProtocol {
    CHAT_COMPLETIONS,
    RESPONSES
  }

  public enum StructuredOutputMode {
    JSON_SCHEMA,
    JSON_OBJECT,
    TEXT
  }

  public AiProviderCapabilities {
    chatCompletionsModes = List.copyOf(chatCompletionsModes);
    responsesModes = List.copyOf(responsesModes);
  }

  public List<StructuredOutputMode> modes(ApiProtocol protocol) {
    return protocol == ApiProtocol.CHAT_COMPLETIONS
        ? chatCompletionsModes
        : responsesModes;
  }

  public boolean supports(ApiProtocol protocol) {
    return !modes(protocol).isEmpty();
  }

  public StructuredOutputMode primaryMode() {
    List<StructuredOutputMode> modes = modes(preferredProtocol);
    if (modes.isEmpty()) {
      throw new IllegalStateException(
          "Provider " + provider + " does not support protocol " + preferredProtocol);
    }
    return modes.get(0);
  }
}
