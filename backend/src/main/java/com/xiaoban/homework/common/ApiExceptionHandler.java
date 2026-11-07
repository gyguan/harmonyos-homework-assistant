package com.xiaoban.homework.common;

import jakarta.validation.ConstraintViolationException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

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

  /**
   * 并发写入的正常结局，不是服务故障：乐观锁 version 失配、同 ID 重试撞主键、
   * 答题/笔记的「先查后插」撞唯一约束都会落到这里。以前统一兜底成 500，
   * 客户端会误判为后端故障并无限重试；返回 409 才能让客户端刷新后按权威状态重试。
   * 只记录异常类名，不回显数据库消息（可能含表名、字段值）。
   */
  @ExceptionHandler({OptimisticLockingFailureException.class, DataIntegrityViolationException.class,
      ConstraintViolationException.class})
  ResponseEntity<Map<String, String>> concurrentConflict(Exception e) {
    log.warn("api concurrent_conflict exception={}", e.getClass().getSimpleName());
    return ResponseEntity.status(HttpStatus.CONFLICT)
        .body(Map.of("message", "数据已在其他设备更新，请刷新后重试"));
  }

  /** 客户端传参类型错误（如 ?w=abc）、请求体不可读、上传超限都是 4xx，不该打 ERROR 堆栈。 */
  @ExceptionHandler({MethodArgumentTypeMismatchException.class, HttpMessageNotReadableException.class,
      MaxUploadSizeExceededException.class})
  ResponseEntity<Map<String, String>> malformedRequest(Exception e) {
    log.debug("api invalid_request exception={}", e.getClass().getSimpleName());
    return ResponseEntity.badRequest().body(Map.of("message", "请求参数不合法"));
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
