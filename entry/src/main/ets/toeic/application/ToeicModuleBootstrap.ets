import { common } from '@kit.AbilityKit';
import { ToeicProgressStore } from '../data/ToeicProgressStore';

export class ToeicModuleBootstrap {
  static async initialize(context:common.UIAbilityContext):Promise<void> {
    await ToeicProgressStore.instance.initialize(context);
  }
}
