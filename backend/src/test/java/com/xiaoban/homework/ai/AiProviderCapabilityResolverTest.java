package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.xiaoban.homework.ai.AiProviderCapabilities.ApiProtocol;
import com.xiaoban.homework.ai.AiProviderCapabilities.Provider;
import com.xiaoban.homework.ai.AiProviderCapabilities.StructuredOutputMode;
import java.util.List;
import org.junit.jupiter.api.Test;

class AiProviderCapabilityResolverTest {
  @Test
  void resolvesOpenAiResponsesWithSchemaFirst() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setProvider("AUTO");
    properties.setBaseUrl("https://api.openai.com");
    properties.setProtocol("responses");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("gpt-5.6-luna");

    assertEquals(Provider.OPENAI, capabilities.provider());
    assertEquals(ApiProtocol.RESPONSES, capabilities.preferredProtocol());
    assertEquals(
        List.of(
            StructuredOutputMode.JSON_SCHEMA,
            StructuredOutputMode.JSON_OBJECT,
            StructuredOutputMode.TEXT),
        capabilities.responsesModes());
  }

  @Test
  void resolvesDeepSeekChatWithoutAssumingJsonSchema() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setProvider("AUTO");
    properties.setBaseUrl("https://api.deepseek.com");
    properties.setProtocol("chat-completions");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("deepseek-v4-flash-0731");

    assertEquals(Provider.DEEPSEEK, capabilities.provider());
    assertEquals(ApiProtocol.CHAT_COMPLETIONS, capabilities.preferredProtocol());
    assertEquals(
        List.of(StructuredOutputMode.JSON_OBJECT, StructuredOutputMode.TEXT),
        capabilities.chatCompletionsModes());
  }

  @Test
  void resolvesGlm47AndAboveToChatWithJsonSchemaFirst() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setProvider("AUTO");
    properties.setBaseUrl("https://open.bigmodel.cn/api/paas/v4");
    properties.setProtocol("responses");

    AiProviderCapabilityResolver resolver = new AiProviderCapabilityResolver(properties);

    for (String model : List.of(
        "glm-4.7",
        "glm-4.7-flash",
        "GLM-4.7-PLUS",
        "glm-5",
        "glm-5.1",
        "glm-5.3")) {
      AiProviderCapabilities capabilities = resolver.resolve(model);
      assertEquals(Provider.ZHIPU_GLM, capabilities.provider(), model);
      assertEquals(ApiProtocol.CHAT_COMPLETIONS, capabilities.preferredProtocol(), model);
      assertEquals(
          List.of(
              StructuredOutputMode.JSON_SCHEMA,
              StructuredOutputMode.JSON_OBJECT,
              StructuredOutputMode.TEXT),
          capabilities.chatCompletionsModes(),
          model);
      assertTrue(capabilities.responsesModes().isEmpty(), model);
    }
  }

  @Test
  void keepsOlderGlmOnJsonObjectCompatibilityPath() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setBaseUrl("https://open.bigmodel.cn/api/paas/v4");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("glm-4.6");

    assertEquals(Provider.ZHIPU_GLM, capabilities.provider());
    assertEquals(ApiProtocol.CHAT_COMPLETIONS, capabilities.preferredProtocol());
    assertEquals(
        List.of(StructuredOutputMode.JSON_OBJECT, StructuredOutputMode.TEXT),
        capabilities.chatCompletionsModes());
    assertFalse(capabilities.chatCompletionsModes().contains(StructuredOutputMode.JSON_SCHEMA));
  }

  @Test
  void resolvesZaiEndpointAsZhipuGlm() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setBaseUrl("https://api.z.ai/api/paas/v4");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("glm-4.7-flash");

    assertEquals(Provider.ZHIPU_GLM, capabilities.provider());
  }

  @Test
  void genericOpenAiCompatibleProviderUsesConservativeModes() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setBaseUrl("https://llm.example.internal/v1");
    properties.setProtocol("chat-completions");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("company-model-v3");

    assertEquals(Provider.GENERIC_OPENAI_COMPATIBLE, capabilities.provider());
    assertEquals(ApiProtocol.CHAT_COMPLETIONS, capabilities.preferredProtocol());
    assertEquals(
        List.of(StructuredOutputMode.JSON_OBJECT, StructuredOutputMode.TEXT),
        capabilities.chatCompletionsModes());
  }

  @Test
  void explicitProviderOverridesAutoDetection() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setProvider("ZHIPU_GLM");
    properties.setBaseUrl("https://proxy.example.internal/v1");

    AiProviderCapabilities capabilities =
        new AiProviderCapabilityResolver(properties).resolve("glm-4.7");

    assertEquals(Provider.ZHIPU_GLM, capabilities.provider());
    assertEquals(ApiProtocol.CHAT_COMPLETIONS, capabilities.preferredProtocol());
  }

  @Test
  void detectsGlm47VersionBoundary() {
    assertFalse(AiProviderCapabilityResolver.isGlm47OrAbove("glm-4.6"));
    assertFalse(AiProviderCapabilityResolver.isGlm47OrAbove("glm-4"));
    assertTrue(AiProviderCapabilityResolver.isGlm47OrAbove("glm-4.7"));
    assertTrue(AiProviderCapabilityResolver.isGlm47OrAbove("glm-4.7-flash"));
    assertTrue(AiProviderCapabilityResolver.isGlm47OrAbove("glm-5"));
    assertTrue(AiProviderCapabilityResolver.isGlm47OrAbove("glm-5.3"));
  }
}
