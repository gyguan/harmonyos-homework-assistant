package com.xiaoban.homework.mediasync;

import java.util.List;

public final class AssignmentMediaSyncDtos {
  private AssignmentMediaSyncDtos() {}

  public record Item(String imageResourceId, long startMs, long endMs, double confidence) {}
  public record Timeline(int version, long durationMs, double confidence, List<Item> items) {}

  public record Response(String status, boolean available, double confidence, long durationMs, List<Item> items) {
    public static Response unavailable(String status) {
      return new Response(status, false, 0, 0, List.of());
    }
  }
}
