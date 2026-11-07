package com.xiaoban.homework.ai;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.ai")
public class AiProviderProperties {
  private String provider = "AUTO";
  private String protocol = "responses";
  private String apiKey = "";
  private String baseUrl = "https://api.openai.com";
  private String responsesPath = "/v1/responses";
  private String chatCompletionsPath = "/v1/chat/completions";
  private String tutorModel = "gpt-5.6-luna";
  private String organizerModel = "";
  private String imageOrganizerModel = "";
  private String practiceModel = "";
  private String mediaSyncTranscriptionModel = "";
  private String mediaSyncTranscriptionsPath = "/v1/audio/transcriptions";
  private String mediaSyncImageModel = "";
  private String mediaSyncAlignmentModel = "";
  private int mediaSyncMaxAiImages = 12;
  private boolean allowUnauthenticated = false;
  private boolean structuredOutput = true;
  private boolean logPayloads = false;
  private boolean disableThinking = true;
  /**
   * Compatibility-only: previous deployments may still supply AI_HOMEWORK_SHORTHAND.
   * Startup imports these entries into homework_organizer_rule once (idempotently);
   * production organizer execution reads only the database. A disabled row will never
   * be silently restored by this old environment setting.
   * Format: 科目|简写|含义|短标题 (optional), separated by semicolons.
   */
  private String homeworkShorthand = "";

  public String getProvider() { return provider; }
  public void setProvider(String provider) { this.provider = value(provider, "AUTO"); }
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
  public String getOrganizerModel() { return blank(organizerModel) ? tutorModel : organizerModel; }
  public void setOrganizerModel(String organizerModel) {
    this.organizerModel = organizerModel == null ? "" : organizerModel.trim();
  }
  public String getImageOrganizerModel() { return blank(imageOrganizerModel) ? getOrganizerModel() : imageOrganizerModel; }
  public void setImageOrganizerModel(String imageOrganizerModel) {
    this.imageOrganizerModel = imageOrganizerModel == null ? "" : imageOrganizerModel.trim();
  }
  public String getPracticeModel() { return blank(practiceModel) ? getOrganizerModel() : practiceModel; }
  public void setPracticeModel(String practiceModel) {
    this.practiceModel = practiceModel == null ? "" : practiceModel.trim();
  }
  public String getMediaSyncTranscriptionModel() { return mediaSyncTranscriptionModel; }
  public void setMediaSyncTranscriptionModel(String mediaSyncTranscriptionModel) {
    this.mediaSyncTranscriptionModel =
        mediaSyncTranscriptionModel == null ? "" : mediaSyncTranscriptionModel.trim();
  }
  public String getMediaSyncTranscriptionsPath() { return mediaSyncTranscriptionsPath; }
  public void setMediaSyncTranscriptionsPath(String mediaSyncTranscriptionsPath) {
    this.mediaSyncTranscriptionsPath =
        path(mediaSyncTranscriptionsPath, "/v1/audio/transcriptions");
  }
  public String getMediaSyncImageModel() {
    return blank(mediaSyncImageModel) ? getImageOrganizerModel() : mediaSyncImageModel;
  }
  public void setMediaSyncImageModel(String mediaSyncImageModel) {
    this.mediaSyncImageModel = mediaSyncImageModel == null ? "" : mediaSyncImageModel.trim();
  }
  public String getMediaSyncAlignmentModel() {
    return blank(mediaSyncAlignmentModel) ? getOrganizerModel() : mediaSyncAlignmentModel;
  }
  public void setMediaSyncAlignmentModel(String mediaSyncAlignmentModel) {
    this.mediaSyncAlignmentModel =
        mediaSyncAlignmentModel == null ? "" : mediaSyncAlignmentModel.trim();
  }
  public int getMediaSyncMaxAiImages() { return mediaSyncMaxAiImages; }
  public void setMediaSyncMaxAiImages(int mediaSyncMaxAiImages) {
    this.mediaSyncMaxAiImages = Math.max(1, Math.min(30, mediaSyncMaxAiImages));
  }
  public boolean isAllowUnauthenticated() { return allowUnauthenticated; }
  public void setAllowUnauthenticated(boolean allowUnauthenticated) { this.allowUnauthenticated = allowUnauthenticated; }
  public boolean isStructuredOutput() { return structuredOutput; }
  public void setStructuredOutput(boolean structuredOutput) { this.structuredOutput = structuredOutput; }
  public boolean isLogPayloads() { return logPayloads; }
  public void setLogPayloads(boolean logPayloads) { this.logPayloads = logPayloads; }
  /** 结构化（整理 / 出题）请求关闭模型思考：思考对抽取类任务没有帮助，只会拖慢 3~4 倍。 */
  public boolean isDisableThinking() { return disableThinking; }
  public void setDisableThinking(boolean disableThinking) { this.disableThinking = disableThinking; }
  public String getHomeworkShorthand() {
    return homeworkShorthand == null ? "" : homeworkShorthand.trim();
  }
  public void setHomeworkShorthand(String homeworkShorthand) {
    this.homeworkShorthand = homeworkShorthand == null ? "" : homeworkShorthand.trim();
  }

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
