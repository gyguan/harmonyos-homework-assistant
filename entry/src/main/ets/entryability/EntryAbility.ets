import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkImportService } from '../application/import/HomeworkImportService';
import { RemoteSubmissionApi } from '../application/remote/RemoteSubmissionApi';
import { HomeworkSubmissionService } from '../application/submission/HomeworkSubmissionService';
import { HomeworkStore } from '../data/HomeworkStore';
import { CoreVisionHomeworkTextExtractor } from '../infrastructure/ai/CoreVisionHomeworkTextExtractor';
import { LocalHomeworkAssignmentParser } from '../infrastructure/ai/LocalHomeworkAssignmentParser';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';

export default class EntryAbility extends UIAbility {
  private loadMainPage(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('pages/Index', (error) => {
        if (error.code) {
          console.error(`Failed to load pages/Index: ${error.code} ${error.message}`);
        }
      });
    } catch {
      console.error('Failed to request loading pages/Index');
    }
  }

  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    HomeworkImportService.instance.configure(
      new CoreVisionHomeworkTextExtractor(),
      new LocalHomeworkAssignmentParser()
    );
    HomeworkSubmissionService.instance.configure(this.context);
    RemoteSubmissionApi.instance.configure(this.context);

    try {
      let persistence = new PreferencesHomeworkPersistence(this.context);
      await HomeworkStore.instance.initialize(persistence);
    } catch {
      console.error('Homework store initialization failed; continuing with in-memory state');
    }

    this.loadMainPage(windowStage);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    void this.bootstrap(windowStage);
  }
}
