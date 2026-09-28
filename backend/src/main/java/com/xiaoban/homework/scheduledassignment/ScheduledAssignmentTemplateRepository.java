package com.xiaoban.homework.scheduledassignment;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScheduledAssignmentTemplateRepository
    extends JpaRepository<ScheduledAssignmentTemplateEntity, UUID> {}
