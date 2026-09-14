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
    Column({ space: 14 }) {
      if (this.scenario === DemoScenario.LOADING) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.PRIMARY);
      } else {
        Text(this.scenario === DemoScenario.ERROR ? '!' : '✓')
          .width(48)
          .height(48)
          .padding({ top: 9 })
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .fontColor(this.scenario === DemoScenario.ERROR ? AppTheme.DANGER : AppTheme.SUCCESS)
          .backgroundColor(this.scenario === DemoScenario.ERROR ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
          .borderRadius(16);
      }

      Text(this.title())
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Text(this.description())
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(21)
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
