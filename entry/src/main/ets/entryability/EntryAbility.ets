import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkImportService } from '../application/import/HomeworkImportService';
import { HomeworkShareImportService } from '../application/import/HomeworkShareImportService';
import { HomeworkCaptureSessionService } from '../application/capture/HomeworkCaptureSessionService';
import { BackendSession } from '../application/remote/BackendSession';
import { RemoteAssignmentResourceApi } from '../application/remote/RemoteAssignmentResourceApi';
import { RemoteSubmissionApi } from '../application/remote/RemoteSubmissionApi';
import { VoiceAssignmentMediaService } from '../application/assignment/VoiceAssignmentMediaService';
import { HomeworkSubmissionService } from '../application/submission/HomeworkSubmissionService';
import { HomeworkLocalBootstrap } from '../data/local/HomeworkLocalBootstrap';
import { HomeworkImportInboxBootstrap } from '../data/local/HomeworkImportInboxBootstrap';
import { HomeworkCaptureSessionBootstrap } from '../data/local/HomeworkCaptureSessionBootstrap';
import { CoreVisionHomeworkTextExtractor } from '../infrastructure/ai/CoreVisionHomeworkTextExtractor';
import { LocalHomeworkAssignmentParser } from '../infrastructure/ai/LocalHomeworkAssignmentParser';
import { NativeHomeworkCaptureRuntime } from '../infrastructure/capture/NativeHomeworkCaptureRuntime';
import { CoreVisionHomeworkCaptureFrameRecognizer } from '../infrastructure/capture/CoreVisionHomeworkCaptureFrameRecognizer';
import { PreferencesBackendSessionStorage } from '../infrastructure/persistence/PreferencesBackendSessionStorage';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';
import { PreferencesHomeworkImportInboxPersistence } from '../infrastructure/persistence/PreferencesHomeworkImportInboxPersistence';
import { PreferencesHomeworkCaptureSessionPersistence } from '../infrastructure/persistence/PreferencesHomeworkCaptureSessionPersistence';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam;
    AppStorage.setOrCreate<string>('shareImportToken', '');
    AppStorage.setOrCreate<boolean>('shareImportForceParent', false);
    this.captureShareImportWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam;
    this.captureShareImportWant(want);
  }

  private captureShareImportWant(want: Want): void {
    let value = want.parameters?.['shareImportToken'];
    if (typeof value !== 'string' || value.length === 0) return;
    AppStorage.setOrCreate<string>('shareImportToken', value);
    AppStorage.setOrCreate<boolean>('shareImportForceParent', true);
    AppStorage.set<string>('shareImportToken', value);
    AppStorage.set<boolean>('shareImportForceParent', true);
  }

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
    HomeworkShareImportService.instance.configure(this.context);
    HomeworkCaptureSessionService.instance.configure(
      new NativeHomeworkCaptureRuntime(), new CoreVisionHomeworkCaptureFrameRecognizer());
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

    try {
      await HomeworkImportInboxBootstrap.instance.initialize(
        new PreferencesHomeworkImportInboxPersistence(this.context));
    } catch {
      console.error('Homework import inbox initialization failed; continuing with in-memory inbox');
    }

    try {
      await HomeworkCaptureSessionBootstrap.instance.initialize(
        new PreferencesHomeworkCaptureSessionPersistence(this.context));
    } catch {
      console.error('Capture session restore failed; continuing with in-memory capture state');
    }

    this.loadMainPage(windowStage);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void { void this.bootstrap(windowStage); }

  onDestroy(): void {
    HomeworkCaptureSessionService.instance.handleAbilityDestroy();
    void HomeworkCaptureSessionService.instance.release();
  }
}
