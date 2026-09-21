import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { Subject } from '../../../domain/model/HomeworkModels';
import {
  HomeworkSourceProfileFormState,
  HomeworkSourceProfileViewModel
} from './HomeworkSourceProfileViewModel';

@Component
export struct HomeworkSourceProfilePage {
  @Prop startCaptureAfterSave: boolean = false;
  onBack: () => void = () => {};
  onSavedAndCapture: () => void = () => {};

  @State private profileName: string = '';
  @State private groupTitle: string = '';
  @State private startTime: string = '15:00';
  @State private chineseTeacher: string = '';
  @State private chineseAliases: string = '';
  @State private mathTeacher: string = '';
  @State private mathAliases: string = '';
  @State private englishTeacher: string = '';
  @State private englishAliases: string = '';
  @State private message: string = '';
  @State private messageError: boolean = false;
  @State private saving: boolean = false;
  private studentId: string = '';
  private profileId: string = '';
  private createdAtEpochMs: number = 0;
  private lastUsedAtEpochMs: number = 0;
  private readonly viewModel: HomeworkSourceProfileViewModel = new HomeworkSourceProfileViewModel();

  aboutToAppear(): void {
    let form = this.viewModel.load();
    this.studentId = form.studentId;
    this.profileId = form.profileId;
    this.createdAtEpochMs = form.createdAtEpochMs;
    this.lastUsedAtEpochMs = form.lastUsedAtEpochMs;
    this.profileName = form.profileName;
    this.groupTitle = form.groupTitle;
    this.startTime = form.startTime;
    this.chineseTeacher = form.chineseTeacher;
    this.chineseAliases = form.chineseAliases;
    this.mathTeacher = form.mathTeacher;
    this.mathAliases = form.mathAliases;
    this.englishTeacher = form.englishTeacher;
    this.englishAliases = form.englishAliases;
  }

  private async saveAndCapture(): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    this.message = '';
    this.messageError = false;
    try {
      let form: HomeworkSourceProfileFormState = {
        studentId: this.studentId,
        profileId: this.profileId,
        createdAtEpochMs: this.createdAtEpochMs,
        lastUsedAtEpochMs: this.lastUsedAtEpochMs,
        profileName: this.profileName,
        groupTitle: this.groupTitle,
        startTime: this.startTime,
        chineseTeacher: this.chineseTeacher,
        chineseAliases: this.chineseAliases,
        mathTeacher: this.mathTeacher,
        mathAliases: this.mathAliases,
        englishTeacher: this.englishTeacher,
        englishAliases: this.englishAliases
      };
      this.viewModel.save(form);
      this.message = '班级采集设置已保存';
      this.onSavedAndCapture();
    } catch (error) {
      this.messageError = true;
      this.message = error instanceof Error ? error.message : '保存失败，请检查输入';
    } finally {
      this.saving = false;
    }
  }

  @Builder
  private TeacherField(label: string, subject: Subject, teacher: string, aliases: string,
    onTeacherChange: (value: string) => void, onAliasesChange: (value: string) => void) {
    Column({ space: 7 }) {
      Text(`${label} · ${subject}`)
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      TextInput({ placeholder: `例如：${label}`, text: teacher })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => onTeacherChange(value));
      TextInput({ placeholder: '别名可用逗号分隔，例如：王老师（语文）,王老师语文', text: aliases })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .fontSize(13)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => onAliasesChange(value));
    }
    .width('100%');
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '班级采集设置',
          subtitle: this.startCaptureAfterSave ? '首次配置一次，以后直接抓取今日作业' : '修改当前孩子的班级群、老师和抓取时间',
          backAccessibilityText: '返回作业导入',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 11 }) {
              Text('班级与微信群')
                .width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
              TextInput({ placeholder: '班级名称，例如：二(3)班', text: this.profileName })
                .width('100%').height(AppTheme.INPUT_HEIGHT)
                .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
                .onChange((value: string) => this.profileName = value);
              TextInput({ placeholder: '微信目标群名称，例如：二(3)班家长群', text: this.groupTitle })
                .width('100%').height(AppTheme.INPUT_HEIGHT)
                .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
                .onChange((value: string) => this.groupTitle = value);
              Column({ space: 5 }) {
                Text('默认抓取开始时间').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
                TextInput({ placeholder: '15:00', text: this.startTime })
                  .width('100%').height(AppTheme.INPUT_HEIGHT)
                  .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
                  .onChange((value: string) => this.startTime = value);
                Text('每天抓取“这个时间到现在”的消息。')
                  .width('100%').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
              }
              .width('100%');
            }
            .width('100%').padding(14).backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);

            Column({ space: 13 }) {
              Text('老师与科目')
                .width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
              this.TeacherField('语文老师', Subject.CHINESE, this.chineseTeacher, this.chineseAliases,
                (value: string) => this.chineseTeacher = value,
                (value: string) => this.chineseAliases = value);
              this.TeacherField('数学老师', Subject.MATH, this.mathTeacher, this.mathAliases,
                (value: string) => this.mathTeacher = value,
                (value: string) => this.mathAliases = value);
              this.TeacherField('英语老师', Subject.ENGLISH, this.englishTeacher, this.englishAliases,
                (value: string) => this.englishTeacher = value,
                (value: string) => this.englishAliases = value);
              Text('没有对应老师的科目可以留空；无法匹配的聊天消息会进入人工确认，不会猜测。')
                .width('100%').fontSize(12).lineHeight(17).fontColor(AppTheme.TERTIARY_TEXT);
            }
            .width('100%').padding(14).backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%').fontSize(13).lineHeight(18)
                .fontColor(this.messageError ? AppTheme.DANGER : AppTheme.SUCCESS)
                .padding(12)
                .backgroundColor(this.messageError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            Button(this.saving ? '正在保存…' :
              (this.startCaptureAfterSave ? '保存并开始抓取' : '保存设置'), { type: ButtonType.Normal })
              .width('100%').height(AppTheme.BUTTON_HEIGHT)
              .enabled(!this.saving)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .backgroundColor(AppTheme.PRIMARY)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.saveAndCapture(); });
          }
          .width('100%')
          .padding({ bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off);
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING });
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
