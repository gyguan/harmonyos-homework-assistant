package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class AiProviderPropertiesTest {
  @Test
  void practiceModelFallsBackToOrganizerModelWhenUnset() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setOrganizerModel("provider-supported-model");
    properties.setPracticeModel("");

    assertEquals("provider-supported-model", properties.getPracticeModel());
  }

  @Test
  void explicitPracticeModelOverridesOrganizerModel() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setOrganizerModel("organizer-model");
    properties.setPracticeModel("practice-model");

    assertEquals("practice-model", properties.getPracticeModel());
  }

  @Test
  void blankPracticeModelFallsBackAfterExplicitValueIsCleared() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setOrganizerModel("organizer-model");
    properties.setPracticeModel("practice-model");
    properties.setPracticeModel("   ");

    assertEquals("organizer-model", properties.getPracticeModel());
  }
}
