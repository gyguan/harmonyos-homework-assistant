package com.xiaoban.homework.auth;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(@NotBlank String loginName, @NotBlank String password) {}
