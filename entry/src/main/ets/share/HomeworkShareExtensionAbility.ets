import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { HomeworkShareReceiveService } from '../application/import/HomeworkShareReceiveService';

const APP_BUNDLE_NAME: string = 'com.gyguan.homeworkassistant';

export default class HomeworkShareExtensionAbility extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    try {
      session.loadContent('pages/HomeworkShareReceivingPage');
    } catch {
      console.error('Homework share receiving page failed to load');
    }
    void this.receiveAndOpen(want, session);
  }

  private async receiveAndOpen(want: Want, session: UIExtensionContentSession): Promise<void> {
    try {
      let data: systemShare.SharedData = await systemShare.getSharedData(want);
      let pending = await new HomeworkShareReceiveService(this.context).receive(data.getRecords());
      await this.context.startAbility({
        bundleName: APP_BUNDLE_NAME,
        abilityName: 'EntryAbility',
        parameters: {
          shareImportToken: pending.token,
          shareImportForceParent: true
        }
      });
    } catch (error) {
      console.error(`Homework system share receive failed: ${error}`);
    } finally {
      try {
        session.terminateSelf();
      } catch {
        console.error('Homework share extension failed to terminate itself');
      }
    }
  }
}
