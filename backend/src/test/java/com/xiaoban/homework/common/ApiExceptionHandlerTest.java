package com.xiaoban.homework.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/** 并发写冲突是正常业务结局，不能像以前那样统一兜底成 500。 */
class ApiExceptionHandlerTest {
  private final ApiExceptionHandler handler = new ApiExceptionHandler();

  @Test
  void optimisticLockingReturnsConflict() {
    ResponseEntity<Map<String, String>> response =
        handler.concurrentConflict(new OptimisticLockingFailureException("stale"));
    assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
    assertTrue(response.getBody().get("message").contains("其他设备"));
  }

  @Test
  void duplicateKeyReturnsConflictWithoutLeakingDatabaseMessage() {
    ResponseEntity<Map<String, String>> response = handler.concurrentConflict(
        new DataIntegrityViolationException("duplicate key value violates unique constraint uq_foo"));
    assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
    assertTrue(!response.getBody().get("message").contains("uq_foo"));
  }

  @Test
  void malformedParameterReturnsBadRequest() {
    ResponseEntity<Map<String, String>> response =
        handler.malformedRequest(new MaxUploadSizeExceededException(1024));
    assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
  }

  @Test
  void unexpectedFailureStillReturnsServerError() {
    assertEquals(HttpStatus.INTERNAL_SERVER_ERROR,
        handler.unexpected(new IllegalStateException("boom")).getStatusCode());
  }
}
