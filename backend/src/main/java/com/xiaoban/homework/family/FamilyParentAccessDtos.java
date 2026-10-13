package com.xiaoban.homework.family;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public final class FamilyParentAccessDtos {
  private FamilyParentAccessDtos() {}

  public record StatusResponse(boolean enabled) {}

  public record CodeRequest(
      @NotBlank
      @Pattern(regexp = "\\d{4}", message = "家长码必须为4位数字")
      String code) {}

  public record VerifyResponse(boolean valid) {}
}
