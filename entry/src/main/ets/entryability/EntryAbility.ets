import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkImportService } from '../application/import/HomeworkImportService';
import { BackendSession } from '../application/remote/BackendSession';
import { RemoteAssignmentResourceApi } from '../application/remote/RemoteAssignmentResourceApi';
import { RemoteSubmissionApi } from '../application/remote/RemoteSubmissionApi';
import { VoiceAssignmentMediaService } from '../application/assignment/VoiceAssignmentMediaService';
import { HomeworkSubmissionService } from '../application/submission/HomeworkSubmissionService';
import { HomeworkLocalBootstrap } from '../data/local/HomeworkLocalBootstrap';
import { CoreVisionHomeworkTextExtractor } from '../infrastructure/ai/CoreVisionHomeworkTextExtractor';
import { LocalHomeworkAssignmentParser } from '../infrastructure/ai/LocalHomeworkAssignmentParser';
import { PreferencesBackendSessionStorage } from '../infrastructure/persistence/PreferencesBackendSessionStorage';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';

export default class EntryAbility extends UIAbility {
  private loadMainPage(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('pages/Index', (error) => {
        if (error.code) console.error(`Failed to load pages/Index: ${error.code} ${error.message}`);
      });
    } catch {
      console.error('Failed to request loading pages/Index');
    }
  }

  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    HomeworkImportService.instance.configure(new CoreVisionHomeworkTextExtractor(), new LocalHomeworkAssignmentParser());
    HomeworkSubmissionService.instance.configure(this.context);
    VoiceAssignmentMediaService.instance.configure(this.context);
    RemoteSubmissionApi.instance.configure(this.context);
    RemoteAssignmentResourceApi.instance.configure(this.context);

    try {
      await BackendSession.instance.initialize(new PreferencesBackendSessionStorage(this.context));
    } catch {
      console.error('Backend session restore failed; continuing offline');
    }

    try {
      await HomeworkLocalBootstrap.instance.initialize(new PreferencesHomeworkPersistence(this.context));
    } catch {
      console.error('Homework store initialization failed; continuing with in-memory state');
    }

    this.loadMainPage(windowStage);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void { void this.bootstrap(windowStage); }
}
