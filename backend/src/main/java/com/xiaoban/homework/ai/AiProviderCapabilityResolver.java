package com.xiaoban.homework.ai;

import com.xiaoban.homework.ai.AiProviderCapabilities.ApiProtocol;
import com.xiaoban.homework.ai.AiProviderCapabilities.Provider;
import com.xiaoban.homework.ai.AiProviderCapabilities.StructuredOutputMode;
import java.net.URI;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Resolves provider capabilities in one place.
 *
 * <p>AUTO detection is intentionally isolated here. Practice/domain code must never inspect model
 * names or provider URLs.
 */
@Component
public class AiProviderCapabilityResolver {
  private static final Pattern GLM_VERSION =
      Pattern.compile("^glm-(\\d+)(?:\\.(\\d+))?(?:[-_].*)?$", Pattern.CASE_INSENSITIVE);

  private final AiProviderProperties properties;

  public AiProviderCapabilityResolver(AiProviderProperties properties) {
    this.properties = properties;
  }

  public AiProviderCapabilities resolve(String model) {
    Provider provider = configuredProvider();
    if (provider == null) provider = detectProvider(properties.getBaseUrl(), model);

    ApiProtocol configuredProtocol = properties.usesChatCompletions()
        ? ApiProtocol.CHAT_COMPLETIONS
        : ApiProtocol.RESPONSES;

    return switch (provider) {
      case OPENAI -> new AiProviderCapabilities(
          provider,
          configuredProtocol,
          List.of(
              StructuredOutputMode.JSON_SCHEMA,
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT),
          List.of(
              StructuredOutputMode.JSON_SCHEMA,
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT));
      case DEEPSEEK -> new AiProviderCapabilities(
          provider,
          configuredProtocol,
          List.of(
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT),
          List.of(
              StructuredOutputMode.JSON_SCHEMA,
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT));
      case ZHIPU_GLM -> zhipuCapabilities(model);
      case GENERIC_OPENAI_COMPATIBLE -> new AiProviderCapabilities(
          provider,
          configuredProtocol,
          List.of(
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT),
          List.of(
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT));
    };
  }

  private AiProviderCapabilities zhipuCapabilities(String model) {
    List<StructuredOutputMode> chatModes = isGlm47OrAbove(model)
        ? List.of(
            StructuredOutputMode.JSON_SCHEMA,
            StructuredOutputMode.JSON_OBJECT,
            StructuredOutputMode.TEXT)
        : List.of(
            StructuredOutputMode.JSON_OBJECT,
            StructuredOutputMode.TEXT);

    return new AiProviderCapabilities(
        Provider.ZHIPU_GLM,
        ApiProtocol.CHAT_COMPLETIONS,
        chatModes,
        List.of());
  }

  private Provider configuredProvider() {
    String configured = properties.getProvider();
    if (configured == null || configured.isBlank() || "AUTO".equalsIgnoreCase(configured)) {
      return null;
    }
    String normalized = configured.trim()
        .toUpperCase(Locale.ROOT)
        .replace('-', '_');
    return switch (normalized) {
      case "OPENAI" -> Provider.OPENAI;
      case "DEEPSEEK" -> Provider.DEEPSEEK;
      case "ZHIPU", "ZHIPU_GLM", "GLM", "ZAI", "Z_AI" -> Provider.ZHIPU_GLM;
      case "GENERIC", "GENERIC_OPENAI_COMPATIBLE", "OPENAI_COMPATIBLE" ->
          Provider.GENERIC_OPENAI_COMPATIBLE;
      default -> throw new IllegalArgumentException("Unsupported AI provider: " + configured);
    };
  }

  static Provider detectProvider(String baseUrl, String model) {
    String host = host(baseUrl);
    String normalizedModel = model == null ? "" : model.trim().toLowerCase(Locale.ROOT);

    if (host.endsWith("bigmodel.cn") || host.equals("api.z.ai") || host.endsWith(".z.ai")) {
      return Provider.ZHIPU_GLM;
    }
    if (host.endsWith("deepseek.com")) return Provider.DEEPSEEK;
    if (host.endsWith("openai.com")) return Provider.OPENAI;

    if (normalizedModel.startsWith("glm-")) return Provider.ZHIPU_GLM;
    if (normalizedModel.startsWith("deepseek-")) return Provider.DEEPSEEK;
    if (normalizedModel.startsWith("gpt-")
        || normalizedModel.matches("^o[134](?:[-.].*)?$")) {
      return Provider.OPENAI;
    }
    return Provider.GENERIC_OPENAI_COMPATIBLE;
  }

  static boolean isGlm47OrAbove(String model) {
    if (model == null) return false;
    Matcher matcher = GLM_VERSION.matcher(model.trim());
    if (!matcher.matches()) return false;

    int major = Integer.parseInt(matcher.group(1));
    int minor = matcher.group(2) == null ? 0 : Integer.parseInt(matcher.group(2));
    return major > 4 || (major == 4 && minor >= 7);
  }

  private static String host(String baseUrl) {
    if (baseUrl == null || baseUrl.isBlank()) return "";
    try {
      String host = URI.create(baseUrl.trim()).getHost();
      return host == null ? "" : host.toLowerCase(Locale.ROOT);
    } catch (Exception ignored) {
      return "";
    }
  }
}
