package com.xiaoban.homework.common;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.http")
public class HttpLogProperties {
  private boolean logPayloads = true;
  private int maxPayloadChars = 20000;

  public boolean isLogPayloads() { return logPayloads; }
  public void setLogPayloads(boolean logPayloads) { this.logPayloads = logPayloads; }
  public int getMaxPayloadChars() { return maxPayloadChars; }
  public void setMaxPayloadChars(int maxPayloadChars) {
    this.maxPayloadChars = Math.max(1000, Math.min(100000, maxPayloadChars));
  }
}
