import { AppTheme } from '../../common/theme/AppTheme';
import { DemoScenario } from '../../common/state/DemoScenario';

@Component
export struct PageStateView {
  @Prop scenario: DemoScenario;

  private title(): string {
    switch (this.scenario) {
      case DemoScenario.LOADING:
        return '正在加载';
      case DemoScenario.EMPTY:
        return '暂时没有内容';
      case DemoScenario.ERROR:
        return '加载失败';
      default:
        return '';
    }
  }

  private description(): string {
    switch (this.scenario) {
      case DemoScenario.LOADING:
        return '正在准备今天的作业，请稍候。';
      case DemoScenario.EMPTY:
        return '当前没有需要处理的作业。';
      case DemoScenario.ERROR:
        return '网络或服务暂时不可用，请稍后再试。';
      default:
        return '';
    }
  }

  build() {
    Column({ space: 12 }) {
      if (this.scenario === DemoScenario.LOADING) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(AppTheme.PRIMARY);
      } else {
        Text(this.scenario === DemoScenario.ERROR ? '!' : '✓')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.scenario === DemoScenario.ERROR ? AppTheme.DANGER : AppTheme.PRIMARY);
      }

      Text(this.title())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);

      Text(this.description())
        .fontSize(14)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
