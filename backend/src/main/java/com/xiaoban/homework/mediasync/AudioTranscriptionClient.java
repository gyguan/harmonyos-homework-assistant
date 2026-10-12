package com.xiaoban.homework.mediasync;

import com.xiaoban.homework.ai.AiProviderProperties;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

@Component
public class AudioTranscriptionClient {
  private static final Logger log = LoggerFactory.getLogger(AudioTranscriptionClient.class);

  private final AiProviderProperties properties;
  private final JsonMapper mapper;
  private final RestClient client;

  public AudioTranscriptionClient(AiProviderProperties properties, JsonMapper mapper) {
    this.properties = properties;
    this.mapper = mapper;
    this.client = RestClient.builder().baseUrl(properties.getBaseUrl()).build();
  }

  public boolean available() {
    String model = properties.getMediaSyncTranscriptionModel();
    return model != null && !model.isBlank() && properties.available(model);
  }

  public Optional<Transcript> transcribe(Path audioPath) {
    if (!available()) return Optional.empty();
    String model = properties.getMediaSyncTranscriptionModel();

    MultipartBodyBuilder body = new MultipartBodyBuilder();
    body.part("file", new FileSystemResource(audioPath));
    body.part("model", model);
    body.part("response_format", "verbose_json");
    body.part("timestamp_granularities[]", "segment");

    long started = System.nanoTime();
    try {
      RestClient.RequestBodySpec request = client.post()
          .uri(properties.getMediaSyncTranscriptionsPath())
          .contentType(MediaType.MULTIPART_FORM_DATA);
      if (properties.getApiKey() != null && !properties.getApiKey().isBlank()) {
        request.header(HttpHeaders.AUTHORIZATION, "Bearer " + properties.getApiKey());
      }
      String response = request.body(body.build()).retrieve().body(String.class);
      if (response == null || response.isBlank()) return Optional.empty();

      Map<?, ?> root = mapper.readValue(response, Map.class);
      List<Segment> segments = segments(root.get("segments"));
      if (segments.isEmpty()) {
        log.warn("[AI] media_sync transcription_empty model={} elapsedMs={}",
            model, elapsedMs(started));
        return Optional.empty();
      }

      long durationMs = segments.get(segments.size() - 1).endMs();
      log.info("[AI] media_sync transcription_ok model={} segments={} durationMs={} elapsedMs={}",
          model, segments.size(), durationMs, elapsedMs(started));
      return Optional.of(new Transcript(model, durationMs, segments));
    } catch (Exception error) {
      log.warn("[AI] media_sync transcription_failed model={} elapsedMs={} exception={} message={}",
          model, elapsedMs(started), error.getClass().getSimpleName(), safe(error.getMessage()));
      return Optional.empty();
    }
  }

  private List<Segment> segments(Object value) {
    if (!(value instanceof List<?> rawSegments)) return List.of();
    List<Segment> result = new ArrayList<>();
    for (Object raw : rawSegments) {
      if (!(raw instanceof Map<?, ?> item)) continue;
      long startMs = secondsToMs(item.get("start"));
      long endMs = secondsToMs(item.get("end"));
      String text = item.get("text") == null ? "" : item.get("text").toString().trim();
      if (text.isBlank() || endMs <= startMs) continue;
      result.add(new Segment(result.size(), startMs, endMs, compact(text, 500)));
      if (result.size() >= 400) break;
    }
    return List.copyOf(result);
  }

  private long secondsToMs(Object value) {
    if (!(value instanceof Number number)) return 0;
    return Math.max(0, Math.round(number.doubleValue() * 1000.0));
  }

  private long elapsedMs(long started) {
    return (System.nanoTime() - started) / 1_000_000L;
  }

  private String safe(String value) {
    if (value == null) return "";
    String text = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    return compact(text, 240);
  }

  private String compact(String value, int max) {
    return value.length() <= max ? value : value.substring(0, max);
  }

  public record Segment(int index, long startMs, long endMs, String text) {}
  public record Transcript(String model, long durationMs, List<Segment> segments) {}
}
