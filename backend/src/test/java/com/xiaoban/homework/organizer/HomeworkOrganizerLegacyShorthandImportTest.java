package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.ai.AiProviderProperties;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkOrganizerLegacyShorthandImportTest {
  @Test void importsOnlyNewLegacyEntriesAndPreservesDisabledExistingOnRestart() {
    var properties = new AiProviderProperties();
    properties.setHomeworkShorthand("数学|周练|每周练习单|完成周练");
    var repository = mock(HomeworkOrganizerRuleRepository.class);
    var importer = new HomeworkOrganizerLegacyShorthandImport(properties, repository);
    when(repository.existsById(any(String.class))).thenReturn(false, true);
    importer.run(null);
    importer.run(null);
    var saved = ArgumentCaptor.forClass(HomeworkOrganizerRuleEntity.class);
    verify(repository, times(1)).save(saved.capture());
    assertEquals("SHORTHAND", saved.getValue().ruleType);
    assertEquals("GLOBAL", saved.getValue().scope);
    assertEquals("数学", saved.getValue().subject);
    assertEquals("周练", saved.getValue().triggerText);
    assertEquals("完成周练", saved.getValue().shortTitle);
    assertEquals("ENV_MIGRATED", saved.getValue().origin);
    assertEquals(1, saved.getValue().version);
    assertEquals(10, saved.getValue().priority);
  }

  @Test void stableIdDoesNotDependOnMeaningSoChangedConfigDoesNotOverrideUserEdits() {
    String one = HomeworkOrganizerLegacyShorthandImport.stableCode("数学", "周练");
    assertEquals(one, HomeworkOrganizerLegacyShorthandImport.stableCode("数学", "周练"));
    assertNotEquals(one, HomeworkOrganizerLegacyShorthandImport.stableCode("英语", "周练"));
  }
}
