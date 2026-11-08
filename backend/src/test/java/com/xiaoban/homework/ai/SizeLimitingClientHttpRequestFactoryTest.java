package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.URI;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpRequest;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.ClientHttpResponse;

class SizeLimitingClientHttpRequestFactoryTest {
  @Test
  void oversizedResponseIsRejectedWhileReading() throws Exception {
    ClientHttpRequest wrapped = wrap(new byte[16], 8);
    ClientHttpResponse response = wrapped.execute();
    assertThrows(IOException.class, () -> response.getBody().readAllBytes());
  }

  @Test
  void responseWithinLimitPassesThroughUnchanged() throws Exception {
    byte[] payload = "{\"ok\":true}".getBytes();
    ClientHttpRequest wrapped = wrap(payload, 64);
    ClientHttpResponse response = wrapped.execute();
    assertArrayEquals(payload, response.getBody().readAllBytes());
    assertEquals(HttpStatusCode.valueOf(200), response.getStatusCode());
  }

  @Test
  void exactlyAtLimitIsAllowed() throws Exception {
    ClientHttpRequest wrapped = wrap(new byte[8], 8);
    assertArrayEquals(new byte[8], wrapped.execute().getBody().readAllBytes());
  }

  private ClientHttpRequest wrap(byte[] payload, int limit) throws IOException {
    ClientHttpResponse response = mock(ClientHttpResponse.class);
    when(response.getBody()).thenReturn(new ByteArrayInputStream(payload));
    when(response.getStatusCode()).thenReturn(HttpStatusCode.valueOf(200));
    ClientHttpRequest request = mock(ClientHttpRequest.class);
    when(request.execute()).thenReturn(response);
    ClientHttpRequestFactory delegate = mock(ClientHttpRequestFactory.class);
    when(delegate.createRequest(any(), any())).thenReturn(request);
    return new SizeLimitingClientHttpRequestFactory(delegate, limit)
        .createRequest(URI.create("http://example.test/v1/chat"), HttpMethod.POST);
  }
}
