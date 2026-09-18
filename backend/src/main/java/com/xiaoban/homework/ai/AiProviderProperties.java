package com.xiaoban.homework.ai;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.ai")
public class AiProviderProperties {
  private String protocol = "responses";
  private String apiKey = "";
  private String baseUrl = "https://api.openai.com";
  private String responsesPath = "/v1/responses";
  private String chatCompletionsPath = "/v1/chat/completions";
  private String tutorModel = "gpt-5.6-luna";
  private String organizerModel = "gpt-5.6-luna";
  private boolean allowUnauthenticated = false;
  private boolean structuredOutput = true;
  private boolean logPayloads = false;

  public String getProtocol() { return protocol; }
  public void setProtocol(String protocol) { this.protocol = value(protocol, "responses"); }
  public String getApiKey() { return apiKey; }
  public void setApiKey(String apiKey) { this.apiKey = apiKey == null ? "" : apiKey.trim(); }
  public String getBaseUrl() { return baseUrl; }
  public void setBaseUrl(String baseUrl) { this.baseUrl = value(baseUrl, "https://api.openai.com"); }
  public String getResponsesPath() { return responsesPath; }
  public void setResponsesPath(String responsesPath) { this.responsesPath = path(responsesPath, "/v1/responses"); }
  public String getChatCompletionsPath() { return chatCompletionsPath; }
  public void setChatCompletionsPath(String chatCompletionsPath) { this.chatCompletionsPath = path(chatCompletionsPath, "/v1/chat/completions"); }
  public String getTutorModel() { return tutorModel; }
  public void setTutorModel(String tutorModel) { this.tutorModel = value(tutorModel, "gpt-5.6-luna"); }
  public String getOrganizerModel() { return organizerModel; }
  public void setOrganizerModel(String organizerModel) { this.organizerModel = value(organizerModel, "gpt-5.6-luna"); }
  public boolean isAllowUnauthenticated() { return allowUnauthenticated; }
  public void setAllowUnauthenticated(boolean allowUnauthenticated) { this.allowUnauthenticated = allowUnauthenticated; }
  public boolean isStructuredOutput() { return structuredOutput; }
  public void setStructuredOutput(boolean structuredOutput) { this.structuredOutput = structuredOutput; }
  public boolean isLogPayloads() { return logPayloads; }
  public void setLogPayloads(boolean logPayloads) { this.logPayloads = logPayloads; }

  public boolean available(String model) {
    return !blank(baseUrl) && !blank(model) && (allowUnauthenticated || !blank(apiKey));
  }

  public boolean usesChatCompletions() {
    return "chat-completions".equalsIgnoreCase(protocol) || "chat_completions".equalsIgnoreCase(protocol);
  }

  private static boolean blank(String value) { return value == null || value.isBlank(); }
  private static String value(String value, String fallback) { return blank(value) ? fallback : value.trim(); }
  private static String path(String value, String fallback) {
    String resolved = value(value, fallback);
    return resolved.startsWith("/") ? resolved : "/" + resolved;
  }
}
