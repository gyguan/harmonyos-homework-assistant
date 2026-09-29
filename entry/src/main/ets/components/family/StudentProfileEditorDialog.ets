import { LayoutPolicy } from '../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../common/theme/AppTheme';

@CustomDialog
export struct StudentProfileEditorDialog {
  controller: CustomDialogController;
  @Link editingId: string;
  @Link editingExisting: boolean;
  @Link editName: string;
  @Link editGrade: string;
  @Link editClassName: string;
  @Link editSemester: string;
  @Link editChineseTextbook: string;
  @Link editMathTextbook: string;
  @Link editEnglishTextbook: string;
  @Link editOtherTextbooks: string;
  @Link deleteStudentConfirmId: string;
  @Link busy: boolean;
  @Link message: string;

  @State private availableWidthVp: number = 480;

  onCancel: () => void = () => {};
  onSave: () => void = () => {};
  onDelete: () => void = () => {};

  private canInlineIdentityFields(): boolean {
    return LayoutPolicy.canSplit(
      this.availableWidthVp,
      LayoutPolicy.settingsInlineFieldsRequirement());
  }

  private cancel(): void {
    if (this.busy) return;
    this.onCancel();
    this.controller.close();
  }

  private updateName(value: string): void {
    this.editName = value;
    this.message = '';
  }

  private updateGrade(value: string): void {
    this.editGrade = value;
    this.message = '';
  }

  private updateClassName(value: string): void {
    this.editClassName = value;
    this.message = '';
  }

  private updateSemester(value: string): void {
    this.editSemester = value;
    this.message = '';
  }

  private updateChineseTextbook(value: string): void {
    this.editChineseTextbook = value;
    this.message = '';
  }

  private updateMathTextbook(value: string): void {
    this.editMathTextbook = value;
    this.message = '';
  }

  private updateEnglishTextbook(value: string): void {
    this.editEnglishTextbook = value;
    this.message = '';
  }

  private updateOtherTextbooks(value: string): void {
    this.editOtherTextbooks = value;
    this.message = '';
  }

  @Builder
  private IdentityFields() {
    if (this.canInlineIdentityFields()) {
      Row({ space: 10 }) {
        TextInput({ placeholder: '年级，如 三年级', text: this.editGrade })
          .layoutWeight(1)
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateGrade(value));
        TextInput({ placeholder: '班级，如 三（2）班', text: this.editClassName })
          .layoutWeight(1)
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateClassName(value));
      }
      .width('100%');
    } else {
      Column({ space: 10 }) {
        TextInput({ placeholder: '年级，如 三年级', text: this.editGrade })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateGrade(value));
        TextInput({ placeholder: '班级，如 三（2）班', text: this.editClassName })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateClassName(value));
      }
      .width('100%');
    }
  }

  @Builder
  private TextbookFields() {
    Column({ space: 10 }) {
      Column({ space: 3 }) {
        Text('教材版本')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('只填写教材版本即可，年级和学期由孩子资料自动组合。')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      Column({ space: 5 }) {
        Row() {
          Text('语文').fontSize(AppTheme.LABEL_TITLE_SIZE).fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.editChineseTextbook.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 2 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.busy)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空语文教材')
              .onClick(() => this.updateChineseTextbook(''));
          }
        }
        .width('100%');
        TextInput({ placeholder: '例如：部编版', text: this.editChineseTextbook })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateChineseTextbook(value));
      }
      .width('100%');

      Column({ space: 5 }) {
        Row() {
          Text('数学').fontSize(AppTheme.LABEL_TITLE_SIZE).fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.editMathTextbook.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 2 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.busy)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空数学教材')
              .onClick(() => this.updateMathTextbook(''));
          }
        }
        .width('100%');
        TextInput({ placeholder: '例如：北师大版', text: this.editMathTextbook })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateMathTextbook(value));
      }
      .width('100%');

      Column({ space: 5 }) {
        Row() {
          Text('英语').fontSize(AppTheme.LABEL_TITLE_SIZE).fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.editEnglishTextbook.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 2 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.busy)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空英语教材')
              .onClick(() => this.updateEnglishTextbook(''));
          }
        }
        .width('100%');
        TextInput({ placeholder: '例如：人教版', text: this.editEnglishTextbook })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateEnglishTextbook(value));
      }
      .width('100%');

      Column({ space: 5 }) {
        Row() {
          Text('其他教材（可选）')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
          Blank();
          if (this.editOtherTextbooks.length > 0) {
            Text('清空')
              .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
              .padding({ left: 12, right: 2 })
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
              .fontColor(AppTheme.PRIMARY)
              .enabled(!this.busy)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('清空其他教材')
              .onClick(() => this.updateOtherTextbooks(''));
          }
        }
        .width('100%');
        TextArea({
          placeholder: '例如：科学=教科版；道德与法治=人教版',
          text: this.editOtherTextbooks
        })
          .width('100%')
          .height(82)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .lineHeight(AppTheme.FORM_TEXT_LINE_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.busy)
          .onChange((value: string) => this.updateOtherTextbooks(value));
        Text('格式：科目=教材版本；多个科目使用中文分号“；”分隔')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private DeleteWarning() {
    if (this.deleteStudentConfirmId === this.editingId) {
      Column({ space: 5 }) {
        Text('确认删除这个孩子？')
          .width('100%')
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.DANGER);
        Text('已有作业的孩子或家庭最后一个孩子仍会被服务端拒绝删除。')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppTheme.DANGER_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private FooterActions() {
    if (this.deleteStudentConfirmId === this.editingId) {
      Row({ space: 10 }) {
        Button('取消删除', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .enabled(!this.busy)
          .onClick(() => this.deleteStudentConfirmId = '');
        Button(this.busy ? '正在删除…' : '确认删除', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.DANGER)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.busy)
          .onClick(() => this.onDelete());
      }
      .width('100%');
    } else {
      Row({ space: 10 }) {
        if (this.editingExisting) {
          Button('删除', { type: ButtonType.Normal })
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .padding({ left: 18, right: 18 })
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.DANGER_SOFT)
            .fontColor(AppTheme.DANGER)
            .enabled(!this.busy)
            .onClick(() => this.deleteStudentConfirmId = this.editingId);
        }
        Button(this.busy ? '正在保存…' : '保存', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.busy)
          .onClick(() => this.onSave());
      }
      .width('100%');
    }
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.editingExisting ? '编辑孩子资料' : '添加孩子')
            .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
            .lineHeight(AppTheme.PAGE_NAV_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('姓名、年级、班级及教材信息')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('取消')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 12, right: 2 })
          .enabled(!this.busy)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('取消编辑孩子资料')
          .onClick(() => this.cancel());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 12 });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 12 }) {
          TextInput({ placeholder: '姓名', text: this.editName })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.busy)
            .onChange((value: string) => this.updateName(value));

          this.IdentityFields();

          TextInput({ placeholder: '学期', text: this.editSemester })
            .width('100%')
            .height(AppTheme.INPUT_HEIGHT)
            .fontSize(AppTheme.FORM_TEXT_SIZE)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.busy)
            .onChange((value: string) => this.updateSemester(value));

          Divider().color(AppTheme.DIVIDER);
          this.TextbookFields();
          this.DeleteWarning();

          if (this.message.length > 0) {
            Text(this.message)
              .width('100%')
              .fontSize(AppTheme.META_SIZE)
              .lineHeight(AppTheme.META_LINE_HEIGHT)
              .fontColor(AppTheme.DANGER);
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 16 });
      }
      .width('100%')
      .constraintSize({ maxHeight: 540 })
      .scrollBar(BarState.Auto);

      Divider().color(AppTheme.DIVIDER);

      Column() {
        this.FooterActions();
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 18 });
    }
    .width('100%')
    .constraintSize({ maxWidth: 600, maxHeight: 720 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(24)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
