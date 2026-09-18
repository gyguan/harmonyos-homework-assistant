package com.xiaoban.homework.tutor;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class TutorDtos {
  private TutorDtos() {}

  public record AskRequest(@NotBlank @Size(max = 2000) String text, Boolean guidanceFirst, Boolean directAnswerAllowed) {
    public boolean guidanceFirstValue() { return guidanceFirst == null || guidanceFirst; }
    public boolean directAnswerAllowedValue() { return directAnswerAllowed != null && directAnswerAllowed; }
  }

  public record Message(UUID id, String role, String content, Instant createdAt) {
    static Message from(TutorMessageEntity entity) {
      return new Message(entity.id, entity.role, entity.content, entity.createdAt);
    }
  }

  public record Conversation(UUID sessionId, boolean available, String notice, List<Message> messages,
      boolean hasMore, long nextBeforeEpochMs) {}
}
