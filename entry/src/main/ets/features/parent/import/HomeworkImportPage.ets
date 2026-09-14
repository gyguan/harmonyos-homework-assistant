import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { MockData } from '../../../data/MockData';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkImportPage {
  @Prop sizeClass: WindowSizeClass;

  @Builder
  private SourcePane() {
    Column({ space: 12 }) {
      Text('老师原始内容').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      Text(MockData.importSource)
        .width('100%')
        .padding(16)
        .fontSize(15)
        .lineHeight(24)
        .fontColor(AppTheme.TEXT)
        .backgroundColor('#F7F8FA')
        .borderRadius(14);
      Text('来源：微信群聊天截图 · 19:01')
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        Button('分享导入').layoutWeight(1);
        Button('截图 OCR').layoutWeight(1);
      }
      .width('100%');
      Row({ space: 8 }) {
        Button('粘贴文本').layoutWeight(1);
        Button('上传文件').layoutWeight(1);
      }
      .width('100%');
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CandidatePane() {
    Column({ space: 10 }) {
      Row() {
        Text('AI 解析结果').fontSize(20).fontWeight(FontWeight.Bold);
        Blank();
        Text('3 项').fontSize(13).fontColor(AppTheme.SUCCESS);
      }
      .width('100%');

      ForEach(MockData.candidates, (item: CandidateAssignment) => {
        Column({ space: 8 }) {
          Row() {
            Text(item.subject).fontSize(12).fontColor(AppTheme.PRIMARY);
            Blank();
            Text(item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');
          Text(item.title).width('100%').fontSize(16).fontWeight(FontWeight.Medium);
          Text('证据：' + item.sourceEvidence)
            .width('100%')
            .fontSize(12)
            .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT)
            .backgroundColor(item.confidence < 0.8 ? '#FFF7E6' : '#F7F8FA')
            .padding(10)
            .borderRadius(10);
          if (item.confidence < 0.8) {
            Text('需要家长确认教材/页码').fontSize(12).fontColor(AppTheme.WARNING);
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(14)
        .border({ width: 1, color: AppTheme.BORDER });
      }, (item: CandidateAssignment) => item.id);

      Button('确认并发布 3 项作业')
        .width('100%')
        .height(48)
        .backgroundColor(AppTheme.PRIMARY);
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('导入老师作业').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('AI 只负责整理，发布前由家长确认').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
            Column() { this.SourcePane(); }.width('45%');
            Column() { this.CandidatePane(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.SourcePane();
          this.CandidatePane();
        }
      }
      .width('100%')
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
