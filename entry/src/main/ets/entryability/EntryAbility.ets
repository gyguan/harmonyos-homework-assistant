import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkImportService } from '../application/import/HomeworkImportService';
import { HomeworkStore } from '../data/HomeworkStore';
import { MockHomeworkAssignmentParser } from '../infrastructure/ai/MockHomeworkAssignmentParser';
import { MockHomeworkTextExtractor } from '../infrastructure/ai/MockHomeworkTextExtractor';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';

export default class EntryAbility extends UIAbility {
  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    HomeworkImportService.instance.configure(
      new MockHomeworkTextExtractor(),
      new MockHomeworkAssignmentParser()
    );
    let persistence = new PreferencesHomeworkPersistence(this.context);
    await HomeworkStore.instance.initialize(persistence);
    windowStage.loadContent('pages/Index');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.bootstrap(windowStage);
  }
}
