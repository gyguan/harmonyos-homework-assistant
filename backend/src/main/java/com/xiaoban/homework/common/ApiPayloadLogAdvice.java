package com.xiaoban.homework.common;

import jakarta.servlet.http.HttpServletRequest;
import java.lang.reflect.Type;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.MethodParameter;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.HttpOutputMessage;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.RequestBodyAdviceAdapter;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;
import tools.jackson.databind.json.JsonMapper;

@ControllerAdvice(annotations = Controller.class)
public class ApiPayloadLogAdvice extends RequestBodyAdviceAdapter implements ResponseBodyAdvice<Object> {
  private static final Logger log = LoggerFactory.getLogger(ApiPayloadLogAdvice.class);

  private final HttpLogProperties properties;
  private final JsonMapper jsonMapper;

  public ApiPayloadLogAdvice(HttpLogProperties properties, JsonMapper jsonMapper) {
    this.properties = properties;
    this.jsonMapper = jsonMapper;
  }

  @Override
  public boolean supports(MethodParameter methodParameter, Type targetType,
      Class<? extends HttpMessageConverter<?>> converterType) {
    return properties.isLogPayloads();
  }

  @Override
  public Object afterBodyRead(Object body, HttpInputMessage inputMessage, MethodParameter parameter,
      Type targetType, Class<? extends HttpMessageConverter<?>> converterType) {
    if (!properties.isLogPayloads()) return body;
    HttpServletRequest request = currentRequest(inputMessage);
    log.info("[HTTP-REQUEST-BODY] requestId={} scene={} body={}",
        requestAttribute(request, AccessLogFilter.ATTR_REQUEST_ID),
        requestAttribute(request, AccessLogFilter.ATTR_CLIENT_SCENE),
        payload(body));
    return body;
  }

  @Override
  public boolean supports(MethodParameter returnType, Class<? extends HttpMessageConverter<?>> converterType) {
    return properties.isLogPayloads();
  }

  @Override
  public Object beforeBodyWrite(Object body, MethodParameter returnType, MediaType selectedContentType,
      Class<? extends HttpMessageConverter<?>> selectedConverterType, ServerHttpRequest request,
      ServerHttpResponse response) {
    if (!properties.isLogPayloads()) return body;
    HttpServletRequest servletRequest = request instanceof ServletServerHttpRequest servlet
        ? servlet.getServletRequest() : null;
    log.info("[HTTP-RESPONSE] requestId={} scene={} status={} body={}",
        requestAttribute(servletRequest, AccessLogFilter.ATTR_REQUEST_ID),
        requestAttribute(servletRequest, AccessLogFilter.ATTR_CLIENT_SCENE),
        responseStatus(response),
        payload(body));
    return body;
  }

  private HttpServletRequest currentRequest(HttpInputMessage inputMessage) {
    if (inputMessage instanceof ServletServerHttpRequest servlet) return servlet.getServletRequest();
    return null;
  }

  private String responseStatus(ServerHttpResponse response) {
    try {
      return response instanceof org.springframework.http.server.ServletServerHttpResponse servlet
          ? Integer.toString(servlet.getServletResponse().getStatus()) : "-";
    } catch (Exception ignored) {
      return "-";
    }
  }

  private String requestAttribute(HttpServletRequest request, String name) {
    if (request == null) return "-";
    Object value = request.getAttribute(name);
    return value == null ? "-" : truncate(value.toString());
  }

  private String payload(Object value) {
    if (value == null) return "<empty>";
    if (value instanceof Resource resource) {
      try {
        return "<binary-resource filename=" + resource.getFilename() + " length=" + resource.contentLength() + ">";
      } catch (Exception ignored) {
        return "<binary-resource>";
      }
    }
    if (value instanceof MultipartFile file) {
      return "<multipart name=" + file.getOriginalFilename() + " contentType=" + file.getContentType()
          + " size=" + file.getSize() + ">";
    }
    if (value instanceof byte[] bytes) return "<binary bytes=" + bytes.length + ">";
    if (value instanceof String text) return sanitizeAndTruncate(text);
    try {
      return sanitizeAndTruncate(jsonMapper.writeValueAsString(value));
    } catch (Exception error) {
      return "<payload-serialization-failed:" + error.getClass().getSimpleName() + ">";
    }
  }

  String sanitizeAndTruncate(String value) {
    String compact = compact(value);
    compact = compact.replaceAll(
        "(?i)(\\\"(?:password|token|api[-_]?key|authorization)\\\"\\s*:\\s*\\\")[^\\\"]*(\\\")",
        "$1***$2");
    compact = compact.replaceAll("(?i)Bearer\\s+[A-Za-z0-9._~+\\-/=]+", "Bearer ***");
    compact = compact.replaceAll("(?i)sk-[A-Za-z0-9_-]{6,}", "sk-***");
    return truncate(compact);
  }

  private String compact(String value) {
    if (value == null) return "<empty>";
    return value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
  }

  private String truncate(String value) {
    if (value == null) return "<empty>";
    int max = properties.getMaxPayloadChars();
    return value.length() <= max ? value : value.substring(0, max) + "...";
  }
}
