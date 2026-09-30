package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class AiProviderPropertiesTest {
  @Test
  void imageModelCanBeChangedIndependentlyAndResetToOrganizer() {
    var properties = new AiProviderProperties();
    properties.setOrganizerModel("text-model");
    assertEquals("text-model", properties.getImageOrganizerModel());
    properties.setImageOrganizerModel("vision-model");
    assertEquals("vision-model", properties.getImageOrganizerModel());
    assertEquals("text-model", properties.getOrganizerModel());
    properties.setImageOrganizerModel(" ");
    assertEquals("text-model", properties.getImageOrganizerModel());
  }
  @Test
  void providerDefaultsToAutoAndCanBeOverridden() {
    AiProviderProperties properties = new AiProviderProperties();

    assertEquals("AUTO", properties.getProvider());

    properties.setProvider("ZHIPU_GLM");
    assertEquals("ZHIPU_GLM", properties.getProvider());

    properties.setProvider("   ");
    assertEquals("AUTO", properties.getProvider());
  }

  @Test
  void organizerAndPracticeFallBackToTutorModelWhenSpecializedModelsAreUnset() {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("provider-supported-model");
    properties.setOrganizerModel("");
    properties.setPracticeModel("");

    assertEquals("provider-supported-model", properties.getOrganizerModel());
    assertEquals("provider-supported-model", properties.getPracticeModel());
  }

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
