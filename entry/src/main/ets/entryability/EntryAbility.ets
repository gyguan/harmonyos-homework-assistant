import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HomeworkStore } from '../data/HomeworkStore';
import { PreferencesHomeworkPersistence } from '../infrastructure/persistence/PreferencesHomeworkPersistence';

export default class EntryAbility extends UIAbility {
  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    let persistence = new PreferencesHomeworkPersistence(this.context);
    await HomeworkStore.instance.initialize(persistence);
    windowStage.loadContent('pages/Index');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.bootstrap(windowStage);
  }
}
