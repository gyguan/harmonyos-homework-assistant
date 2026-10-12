package com.xiaoban.homework.mediasync;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class RuleMediaTimelineAligner {
  private static final Pattern EXPLICIT_IMAGE = Pattern.compile(
      "第\\s*([0-9一二三四五六七八九十]+)\\s*[张幅]");

  public Optional<Result> align(
      AudioTranscriptionClient.Transcript transcript,
      List<String> imageResourceIds) {
    if (transcript == null || transcript.segments().isEmpty() || imageResourceIds.isEmpty()) {
      return Optional.empty();
    }
    int imageCount = imageResourceIds.size();
    long[] starts = new long[imageCount];
    boolean[] seen = new boolean[imageCount];
    starts[0] = 0;
    seen[0] = true;
    int current = 0;

    for (AudioTranscriptionClient.Segment segment : transcript.segments()) {
      String text = normalize(segment.text());
      if (text.isBlank()) continue;
      if (containsPrevious(text)) return Optional.empty();

      Matcher matcher = EXPLICIT_IMAGE.matcher(text);
      if (matcher.find()) {
        int ordinal = ordinal(matcher.group(1));
        if (ordinal <= 0 || ordinal > imageCount) continue;
        int target = ordinal - 1;
        if (target < current) return Optional.empty();
        current = target;
        if (!seen[target]) {
          starts[target] = target == 0 ? 0 : segment.startMs();
          seen[target] = true;
        }
        continue;
      }

      if (containsNext(text) && current + 1 < imageCount) {
        current++;
        if (!seen[current]) {
          starts[current] = segment.startMs();
          seen[current] = true;
        }
      }
    }

    for (boolean item : seen) {
      if (!item) return Optional.empty();
    }
    for (int i = 1; i < starts.length; i++) {
      if (starts[i] < starts[i - 1]) return Optional.empty();
    }

    List<MediaSyncAlignmentClient.Boundary> boundaries = new ArrayList<>();
    for (int i = 0; i < imageCount; i++) {
      long end = i + 1 < imageCount ? starts[i + 1] : transcript.durationMs();
      if (end < starts[i]) return Optional.empty();
      boundaries.add(new MediaSyncAlignmentClient.Boundary(
          imageResourceIds.get(i), starts[i], end, 0.92));
    }
    return Optional.of(new Result(
        0.92, transcript.durationMs(), List.copyOf(boundaries)));
  }

  private boolean containsNext(String text) {
    return text.contains("下一张") || text.contains("下一幅") || text.contains("下一页")
        || text.contains("翻到下一页") || text.contains("看下一页");
  }

  private boolean containsPrevious(String text) {
    return text.contains("上一张") || text.contains("上一幅") || text.contains("上一页")
        || text.contains("返回前一页");
  }

  private String normalize(String value) {
    return value == null ? "" : value.replace(" ", "").replace("　", "");
  }

  private int ordinal(String value) {
    if (value == null || value.isBlank()) return -1;
    try {
      return Integer.parseInt(value);
    } catch (NumberFormatException ignored) {
      // Chinese ordinal below.
    }
    if ("十".equals(value)) return 10;
    int tens = value.indexOf('十');
    if (tens >= 0) {
      int left = tens == 0 ? 1 : chineseDigit(value.charAt(0));
      int right = tens == value.length() - 1 ? 0 : chineseDigit(value.charAt(tens + 1));
      if (left < 0 || right < 0) return -1;
      return left * 10 + right;
    }
    return value.length() == 1 ? chineseDigit(value.charAt(0)) : -1;
  }

  private int chineseDigit(char value) {
    return switch (value) {
      case '一' -> 1;
      case '二' -> 2;
      case '三' -> 3;
      case '四' -> 4;
      case '五' -> 5;
      case '六' -> 6;
      case '七' -> 7;
      case '八' -> 8;
      case '九' -> 9;
      default -> -1;
    };
  }

  public record Result(
      double confidence,
      long durationMs,
      List<MediaSyncAlignmentClient.Boundary> boundaries) {}
}
