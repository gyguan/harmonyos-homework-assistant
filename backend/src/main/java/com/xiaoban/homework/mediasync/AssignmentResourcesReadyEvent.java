package com.xiaoban.homework.mediasync;

import java.util.UUID;

public record AssignmentResourcesReadyEvent(UUID familyId, String assignmentId) {}
