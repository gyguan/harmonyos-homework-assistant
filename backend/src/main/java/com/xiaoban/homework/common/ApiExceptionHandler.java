package com.xiaoban.homework.common;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {
  private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);
  @ExceptionHandler(ApiExceptions.NotFound.class)
  ResponseEntity<Map<String, String>> notFound(RuntimeException e) { return error(HttpStatus.NOT_FOUND, e); }

  @ExceptionHandler(ApiExceptions.Conflict.class)
  ResponseEntity<Map<String, String>> conflict(RuntimeException e) { return error(HttpStatus.CONFLICT, e); }

  @ExceptionHandler(ApiExceptions.Unauthorized.class)
  ResponseEntity<Map<String, String>> unauthorized(RuntimeException e) { return error(HttpStatus.UNAUTHORIZED, e); }

  @ExceptionHandler(ApiExceptions.BadRequest.class)
  ResponseEntity<Map<String, String>> badRequest(RuntimeException e) { return error(HttpStatus.BAD_REQUEST, e); }

  @ExceptionHandler(ApiExceptions.ServiceUnavailable.class)
  ResponseEntity<Map<String, String>> serviceUnavailable(RuntimeException e) {
    log.warn("api service_unavailable exception={} message={}",
        e.getClass().getSimpleName(), safeMessage(e.getMessage()));
    return error(HttpStatus.SERVICE_UNAVAILABLE, e);
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ResponseEntity<Map<String, String>> validation(MethodArgumentNotValidException e) {
    String message = e.getBindingResult().getFieldErrors().stream().findFirst()
        .map(it -> it.getField() + ": " + it.getDefaultMessage()).orElse("请求参数不合法");
    return ResponseEntity.badRequest().body(Map.of("message", message));
  }

  @ExceptionHandler(Exception.class)
  ResponseEntity<Map<String, String>> unexpected(Exception e) {
    log.error("api unexpected_error exception={} message={}",
        e.getClass().getSimpleName(), safeMessage(e.getMessage()), e);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(Map.of("message", "服务暂时不可用，请稍后重试"));
  }

  private ResponseEntity<Map<String, String>> error(HttpStatus status, RuntimeException e) {
    return ResponseEntity.status(status).body(Map.of("message", e.getMessage()));
  }

  private String safeMessage(String value) {
    if (value == null || value.isBlank()) return "-";
    String compact = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    return compact.length() <= 300 ? compact : compact.substring(0, 300);
  }
}
