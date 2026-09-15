package com.xiaoban.homework.tutor;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class ConfigurableTutorModelClient implements TutorModelClient {
  private final AiProviderProperties properties;
  private final OpenAiCompatibleTransport transport;

  public ConfigurableTutorModelClient(AiProviderProperties properties, OpenAiCompatibleTransport transport) {
    this.properties = properties;
    this.transport = transport;
  }

  @Override
  public boolean available() {
    return transport.available(properties.getTutorModel());
  }

  @Override
  public Optional<String> answer(TutorModelRequest request) {
    return transport.complete(
        properties.getTutorModel(),
        request.instructions(),
        request.input(),
        700,
        null,
        null);
  }
}
