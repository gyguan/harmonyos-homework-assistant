import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkImportService } from '../application/import/HomeworkImportService';
import { HomeworkSubmissionService } from '../application/submission/HomeworkSubmissionService';
import { HomeworkStore } from '../data/HomeworkStore';
import { CoreVisionHomeworkTextExtractor } from '../infrastructure/ai/CoreVisionHomeworkTextExtractor';
import { LocalHomeworkAssignmentParser } from '../infrastructure/ai/LocalHomeworkAssignmentParser';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';

export default class EntryAbility extends UIAbility {
  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    HomeworkImportService.instance.configure(
      new CoreVisionHomeworkTextExtractor(),
      new LocalHomeworkAssignmentParser()
    );
    HomeworkSubmissionService.instance.configure(this.context);
    let persistence = new PreferencesHomeworkPersistence(this.context);
    await HomeworkStore.instance.initialize(persistence);
    windowStage.loadContent('pages/Index');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.bootstrap(windowStage);
  }
}
