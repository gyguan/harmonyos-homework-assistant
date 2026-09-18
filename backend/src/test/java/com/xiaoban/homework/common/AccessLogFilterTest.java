package com.xiaoban.homework.common;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class AccessLogFilterTest {
  @Test
  void detectsOnlySameRequestKeyInsideDuplicateWindow() {
    AccessLogFilter filter = new AccessLogFilter(new HttpLogProperties());

    assertFalse(filter.isDuplicate("10.0.0.1", "GET%7C%2Fapi%2Fv1%2Fstudents", 1000));
    assertTrue(filter.isDuplicate("10.0.0.1", "GET%7C%2Fapi%2Fv1%2Fstudents", 2000));
    assertFalse(filter.isDuplicate("10.0.0.1", "GET%7C%2Fapi%2Fv1%2Fstudents%3Fpage%3D1", 2200));
    assertFalse(filter.isDuplicate("10.0.0.2", "GET%7C%2Fapi%2Fv1%2Fstudents", 2300));
    assertFalse(filter.isDuplicate("10.0.0.1", "GET%7C%2Fapi%2Fv1%2Fstudents", 5000));
  }

  @Test
  void sanitizesCorrelationHeadersBeforeLogging() {
    AccessLogFilter filter = new AccessLogFilter(new HttpLogProperties());

    assertEquals("assignment.sync", filter.safeHeader("assignment.sync", 80));
    assertEquals("bad__scene", filter.safeHeader("bad\r\nscene", 80));
    assertEquals("-", filter.safeHeader(null, 80));
  }
}
