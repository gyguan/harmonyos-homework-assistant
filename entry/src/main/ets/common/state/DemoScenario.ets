export enum DemoScenario {
  NORMAL = 'NORMAL',
  LOADING = 'LOADING',
  EMPTY = 'EMPTY',
  ERROR = 'ERROR',
  OFFLINE = 'OFFLINE',
  TUTOR_UNAVAILABLE = 'TUTOR_UNAVAILABLE'
}

export class DemoScenarioHelper {
  static readonly ORDER: DemoScenario[] = [
    DemoScenario.NORMAL,
    DemoScenario.LOADING,
    DemoScenario.EMPTY,
    DemoScenario.ERROR,
    DemoScenario.OFFLINE,
    DemoScenario.TUTOR_UNAVAILABLE
  ];

  static next(current: DemoScenario): DemoScenario {
    const index = DemoScenarioHelper.ORDER.indexOf(current);
    return DemoScenarioHelper.ORDER[(index + 1) % DemoScenarioHelper.ORDER.length];
  }

  static label(scenario: DemoScenario): string {
    switch (scenario) {
      case DemoScenario.LOADING:
        return '加载中';
      case DemoScenario.EMPTY:
        return '空数据';
      case DemoScenario.ERROR:
        return '错误';
      case DemoScenario.OFFLINE:
        return '离线';
      case DemoScenario.TUTOR_UNAVAILABLE:
        return 'AI不可用';
      default:
        return '正常';
    }
  }
}
