package com.xiaoban.homework.ai;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.net.URI;
import org.springframework.http.HttpMethod;
import org.springframework.http.client.ClientHttpRequest;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.ClientHttpResponse;

/**
 * 给 AI 上游响应体加硬上限。
 *
 * <p>{@code RestClient.retrieve().body(String.class)} 会把整个响应读进一个字符串；
 * 上游一旦异常返回几 GB 内容（或被代理注入错误页），JVM 会直接 OOM，而不是报一次
 * 可重试的 AI 失败。这里在 HTTP 层包一层限界流，超过上限立刻抛 IOException，
 * 由调用方现有的异常处理降级成「AI 暂时不可用」。
 *
 * <p>用 JDK 动态代理装饰请求/响应，而不是实现 {@code ClientHttpRequest} 的全部方法：
 * Spring 7 之后该接口方法集合会随版本增加，代理可以自动跟随，不会因为升级 Spring
 * 漏实现一个 default 方法而在运行时炸掉。
 */
final class SizeLimitingClientHttpRequestFactory implements ClientHttpRequestFactory {
  static final int DEFAULT_MAX_RESPONSE_BYTES = 2 * 1024 * 1024;

  private final ClientHttpRequestFactory delegate;
  private final int maxResponseBytes;

  SizeLimitingClientHttpRequestFactory(ClientHttpRequestFactory delegate) {
    this(delegate, DEFAULT_MAX_RESPONSE_BYTES);
  }

  SizeLimitingClientHttpRequestFactory(ClientHttpRequestFactory delegate, int maxResponseBytes) {
    this.delegate = delegate;
    this.maxResponseBytes = maxResponseBytes;
  }

  @Override
  public ClientHttpRequest createRequest(URI uri, HttpMethod httpMethod) throws IOException {
    ClientHttpRequest request = delegate.createRequest(uri, httpMethod);
    return (ClientHttpRequest) Proxy.newProxyInstance(
        ClientHttpRequest.class.getClassLoader(),
        new Class<?>[] {ClientHttpRequest.class},
        (proxy, method, args) -> {
          try {
            Object result = method.invoke(request, args);
            if ("execute".equals(method.getName()) && result instanceof ClientHttpResponse response) {
              return limitBody(response);
            }
            return result;
          } catch (InvocationTargetException failure) {
            throw failure.getCause();
          }
        });
  }

  private ClientHttpResponse limitBody(ClientHttpResponse response) {
    return (ClientHttpResponse) Proxy.newProxyInstance(
        ClientHttpResponse.class.getClassLoader(),
        new Class<?>[] {ClientHttpResponse.class},
        (proxy, method, args) -> {
          try {
            Object result = method.invoke(response, args);
            if ("getBody".equals(method.getName()) && result instanceof InputStream body) {
              return new LimitedInputStream(body, maxResponseBytes);
            }
            return result;
          } catch (InvocationTargetException failure) {
            throw failure.getCause();
          }
        });
  }

  static final class LimitedInputStream extends FilterInputStream {
    private final long limit;
    private long read;

    LimitedInputStream(InputStream input, long limit) {
      super(input);
      this.limit = limit;
    }

    @Override
    public int read() throws IOException {
      int value = super.read();
      if (value >= 0) account(1);
      return value;
    }

    @Override
    public int read(byte[] buffer, int offset, int length) throws IOException {
      int count = super.read(buffer, offset, length);
      if (count > 0) account(count);
      return count;
    }

    @Override
    public long skip(long count) throws IOException {
      long skipped = super.skip(count);
      if (skipped > 0) account(skipped);
      return skipped;
    }

    private void account(long count) throws IOException {
      read += count;
      if (read > limit) {
        throw new IOException("AI response body exceeds " + limit + " bytes");
      }
    }
  }
}
