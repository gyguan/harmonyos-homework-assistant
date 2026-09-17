package com.xiaoban.homework.common;

import java.util.Map;
import org.springframework.boot.availability.ApplicationAvailability;
import org.springframework.boot.availability.ReadinessState;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/health")
public class HealthController {
  private final ApplicationAvailability availability;

  public HealthController(ApplicationAvailability availability) {
    this.availability = availability;
  }

  @GetMapping
  public ResponseEntity<Map<String, String>> health() {
    if (availability.getReadinessState() != ReadinessState.ACCEPTING_TRAFFIC) {
      return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of("status", "STARTING"));
    }
    return ResponseEntity.ok(Map.of("status", "UP"));
  }
}
