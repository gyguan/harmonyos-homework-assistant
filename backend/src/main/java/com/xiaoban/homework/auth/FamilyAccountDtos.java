package com.xiaoban.homework.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class FamilyAccountDtos {
  private FamilyAccountDtos() {}

  public record CreateRequest(
      @NotBlank @Size(max = 120) String loginName,
      @NotBlank @Size(min = 6, max = 120) String password,
      @NotBlank @Size(max = 120) String displayName) {}

  public record Item(
      String id,
      String loginName,
      String displayName,
      boolean mine) {}

  public record Response(List<Item> accounts) {}
}
