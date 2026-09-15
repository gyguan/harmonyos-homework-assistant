import { AppTheme } from '../common/theme/AppTheme';
import { HomeworkStore } from '../data/HomeworkStore';
import { StudentProfile } from '../domain/model/HomeworkModels';

@Component
export struct PersonEntryPage {
  @Prop revision: number = 0;
  onSelectParent: () => void = () => {};
  onSelectStudent: (studentId: string) => void = () => {};

  private students(): StudentProfile[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getStudents();
  }

  @Builder
  private BrandHeader() {
    Column({ space: 12 }) {
      Text('伴').width(52).height(52).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT_ON_PRIMARY)
        .textAlign(TextAlign.Center).padding({ top: 12 }).backgroundColor(AppTheme.PRIMARY).borderRadius(16);
      Text('小伴作业').fontSize(30).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      Text('今天是谁在使用？').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text('选择后进入对应空间。孩子只看到自己的作业，家长可以管理多个孩子。')
        .fontSize(AppTheme.BODY_SIZE).lineHeight(22).fontColor(AppTheme.SUBTEXT).textAlign(TextAlign.Center);
    }.width('100%').alignItems(HorizontalAlign.Center).margin({ bottom: 16 });
  }

  @Builder
  private ParentCard() {
    Row({ space: 14 }) {
      Text('家').width(48).height(48).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT_ON_PRIMARY)
        .textAlign(TextAlign.Center).padding({ top: 12 }).backgroundColor(AppTheme.PRIMARY).borderRadius(15);
      Column({ space: 5 }) {
        Text('家长').width('100%').fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('收作业、确认任务、查看孩子完成情况').width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Text('›').fontSize(24).fontColor(AppTheme.TERTIARY_TEXT);
    }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CARD_RADIUS).onClick(() => this.onSelectParent());
  }

  @Builder
  private StudentCard(student: StudentProfile) {
    Row({ space: 14 }) {
      Text(student.name.substring(0, 1)).width(48).height(48).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center).padding({ top: 12 }).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(15);
      Column({ space: 5 }) {
        Text(student.name).width('100%').fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(`${student.grade} · ${student.className}`).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Text('›').fontSize(24).fontColor(AppTheme.TERTIARY_TEXT);
    }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CARD_RADIUS).onClick(() => this.onSelectStudent(student.id));
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.ITEM_GAP }) {
        this.BrandHeader();
        Text('家长').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT).margin({ left: 4 });
        this.ParentCard();
        Text('孩子').width('100%').fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT).margin({ left: 4, top: 8 });
        ForEach(this.students(), (student: StudentProfile) => {
          this.StudentCard(student);
        }, (student: StudentProfile) => student.id);
        Row({ space: 8 }) {
          Text('●').fontSize(8).fontColor(AppTheme.SUCCESS);
          Text('进入后身份固定，避免家庭成员之间误操作。').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%').padding({ top: 10, left: 4 });
      }.width('100%').padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 48, bottom: 40 });
    }.width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
