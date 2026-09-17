import { BackendAuthService } from '../../../application/remote/BackendAuthService';
import { BackendSession } from '../../../application/remote/BackendSession';
import { FamilyCloudService } from '../../../application/remote/FamilyCloudService';
import { HomeworkSyncService } from '../../../application/remote/HomeworkSyncService';
import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { SettingsToggleRow } from '../../../components/selection/SelectionControls';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { StudentProfile } from '../../../domain/model/HomeworkModels';

@Component
export struct BackendConnectionPage {
  @State private availableWidthVp: number = 390;
  @State private baseUrl: string = '';
  @State private loginName: string = 'parent';
  @State private password: string = '';
  @State private message: string = '';
  @State private connecting: boolean = false;
  @State private pageRevision: number = 0;
  @State private editingId: string = '';
  @State private editName: string = '';
  @State private editGrade: string = '';
  @State private editClassName: string = '';
  @State private editSemester: string = '';
  @State private editTextbooks: string = '';
  @State private cloudPanelOpen: boolean = false;
  @State private deleteStudentConfirmId: string = '';
  onStoreChanged: () => void = () => {};

  aboutToAppear(): void {
    this.baseUrl = BackendSession.instance.getBaseUrl();
    if (BackendSession.instance.isConnected()) void this.refreshStudents();
  }

  private canInlineStudentFields(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.settingsInlineFieldsRequirement());
  }

  private students(): StudentProfile[] {
    let currentRevision = this.pageRevision;
    return HomeworkStore.instance.getStudents();
  }

  private tutorGuidanceFirst(): boolean {
    let currentRevision = this.pageRevision;
    return HomeworkStore.instance.getSettings().tutorGuidanceFirst;
  }

  private directAnswerAllowed(): boolean {
    let currentRevision = this.pageRevision;
    return HomeworkStore.instance.getSettings().directAnswerAllowed;
  }

  private updateTutorSettings(guidanceFirst: boolean, directAnswerAllowed: boolean): void {
    HomeworkStore.instance.updateTutorSettings(guidanceFirst, directAnswerAllowed);
    this.pageRevision++;
    this.message = 'AI 辅导规则已保存';
    this.onStoreChanged();
  }

  private async connect(): Promise<void> {
    if (this.baseUrl.trim().length === 0 || this.loginName.trim().length === 0 || this.password.length === 0) {
      this.message = '请填写服务地址、账号和密码';
      return;
    }
    this.connecting = true;
    this.message = '正在连接…';
    try {
      let displayName = await BackendAuthService.instance.login(this.baseUrl, this.loginName, this.password);
      let familySynced = await FamilyCloudService.instance.syncStudents();
      let homeworkSynced = await HomeworkSyncService.instance.syncActiveStudent();
      this.pageRevision++;
      this.message = familySynced && homeworkSynced ? `已连接：${displayName}，家庭数据已同步` : `已登录：${displayName}，部分数据稍后再同步`;
      this.onStoreChanged();
    } catch {
      this.message = '连接失败，请检查电脑局域网地址、后端服务和账号密码';
    } finally {
      this.connecting = false;
    }
  }

  private async refreshStudents(): Promise<void> {
    if (await FamilyCloudService.instance.syncStudents()) {
      this.pageRevision++;
      this.onStoreChanged();
    }
  }

  private beginAdd(): void {
    this.deleteStudentConfirmId = '';
    this.editingId = `student-${Date.now()}`;
    this.editName = '';
    this.editGrade = '';
    this.editClassName = '';
    this.editSemester = '上学期';
    this.editTextbooks = '';
  }

  private beginEdit(student: StudentProfile): void {
    this.deleteStudentConfirmId = '';
    this.editingId = student.id;
    this.editName = student.name;
    this.editGrade = student.grade;
    this.editClassName = student.className;
    this.editSemester = student.semester;
    this.editTextbooks = student.textbookSummary;
  }

  private cancelEdit(): void {
    this.deleteStudentConfirmId = '';
    this.editingId = '';
  }

  private editingExistingStudent(): boolean {
    for (let student of this.students()) if (student.id === this.editingId) return true;
    return false;
  }

  private async saveStudent(): Promise<void> {
    if (this.editName.trim().length === 0 || this.editGrade.trim().length === 0 || this.editClassName.trim().length === 0) {
      this.message = '姓名、年级、班级不能为空';
      return;
    }
    let student: StudentProfile = {
      id: this.editingId,
      name: this.editName.trim(),
      grade: this.editGrade.trim(),
      className: this.editClassName.trim(),
      semester: this.editSemester.trim().length === 0 ? '上学期' : this.editSemester.trim(),
      textbookSummary: this.editTextbooks.trim()
    };
    if (await FamilyCloudService.instance.saveStudent(student)) {
      this.editingId = '';
      this.deleteStudentConfirmId = '';
      this.pageRevision++;
      this.message = '孩子资料已保存并同步';
      this.onStoreChanged();
      HomeworkSyncService.instance.requestSync();
    } else {
      this.message = '保存失败，请确认云端连接';
    }
  }

  private async deleteStudent(studentId: string): Promise<void> {
    if (await FamilyCloudService.instance.deleteStudent(studentId)) {
      this.editingId = '';
      this.deleteStudentConfirmId = '';
      this.pageRevision++;
      this.message = '孩子资料已删除';
      this.onStoreChanged();
    } else {
      this.deleteStudentConfirmId = '';
      this.message = '删除失败：已有作业的孩子或家庭最后一个孩子不能直接删除';
    }
  }

  private async disconnect(): Promise<void> {
    await BackendAuthService.instance.logout();
    this.message = '已断开云端连接，本地作业仍可继续使用';
    this.pageRevision++;
  }

  @Builder
  private SectionTitle(title: string, description: string) {
    Column({ space: 3 }) {
      Text(title).width('100%').fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text(description).width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private StudentIdentityFields() {
    if (this.canInlineStudentFields()) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '年级，如 三年级', text: this.editGrade })
          .layoutWeight(1).height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editGrade = value);
        TextInput({ placeholder: '班级，如 三（2）班', text: this.editClassName })
          .layoutWeight(1).height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editClassName = value);
      }
      .width('100%');
    } else {
      Column({ space: 8 }) {
        TextInput({ placeholder: '年级，如 三年级', text: this.editGrade })
          .width('100%').height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editGrade = value);
        TextInput({ placeholder: '班级，如 三（2）班', text: this.editClassName })
          .width('100%').height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editClassName = value);
      }
      .width('100%');
    }
  }

  @Builder
  private StudentEditor() {
    if (this.editingId.length > 0) {
      Column({ space: 10 }) {
        Row() {
          Text(this.editingExistingStudent() ? '编辑孩子资料' : '添加孩子')
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Blank();
          Text('取消').constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
            .fontSize(13).fontColor(AppTheme.PRIMARY).textAlign(TextAlign.Center)
            .accessibilityRole(AccessibilityRoleType.BUTTON).accessibilityText('取消编辑孩子资料')
            .onClick(() => this.cancelEdit());
        }
        .width('100%');

        TextInput({ placeholder: '姓名', text: this.editName })
          .width('100%').height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editName = value);

        this.StudentIdentityFields();

        TextInput({ placeholder: '学期', text: this.editSemester })
          .width('100%').height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editSemester = value);
        TextArea({ placeholder: '教材版本，如 语文部编版 · 数学北师大版', text: this.editTextbooks })
          .width('100%').height(86).backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.editTextbooks = value);

        if (this.deleteStudentConfirmId === this.editingId) {
          Column({ space: 8 }) {
            Text('确认删除这个孩子？').width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.DANGER);
            Text('删除家庭成员属于高风险操作。已有作业的孩子或家庭最后一个孩子仍会被服务端拒绝删除。')
              .width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
            Row({ space: 8 }) {
              Button('取消删除', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
                .onClick(() => this.deleteStudentConfirmId = '');
              Button('确认删除', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.DANGER).fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => { void this.deleteStudent(this.editingId); });
            }
            .width('100%');
          }
          .width('100%').padding(12).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
        } else {
          Row({ space: 8 }) {
            if (this.editingExistingStudent()) {
              Button('删除', { type: ButtonType.Normal }).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .padding({ left: 18, right: 18 }).borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.DANGER_SOFT).fontColor(AppTheme.DANGER)
                .onClick(() => this.deleteStudentConfirmId = this.editingId);
            }
            Button('保存', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.saveStudent(); });
          }
          .width('100%');
        }
      }
      .width('100%').padding(14).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private FamilySection() {
    Column({ space: 0 }) {
      ForEach(this.students(), (student: StudentProfile) => {
        Row({ space: 12 }) {
          Text(student.name.length > 0 ? student.name.substring(0, 1) : '伴')
            .width(38).height(38).padding({ top: 9 }).textAlign(TextAlign.Center).fontSize(15)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(12);
          Column({ space: 3 }) {
            Text(student.name).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text(`${student.grade} · ${student.className} · ${student.semester}`).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start);
          Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%').constraintSize({ minHeight: 60 }).padding({ top: 12, bottom: 12 })
        .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`${student.name}，${student.grade}，${student.className}，编辑资料`)
        .onClick(() => this.beginEdit(student));
        Divider().color(AppTheme.DIVIDER);
      }, (student: StudentProfile) => student.id);

      if (BackendSession.instance.isConnected()) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.plus_square')).fontSize(18).fontColor([AppTheme.PRIMARY]);
          Text('添加孩子').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
        }
        .width('100%').constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET }).padding({ top: 13, bottom: 13 })
        .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON).accessibilityText('添加孩子')
        .onClick(() => this.beginAdd());
      } else {
        Text('连接家庭云端后可新增或修改家庭成员。').width('100%').padding({ top: 12, bottom: 12 })
          .fontSize(12).fontColor(AppTheme.SUBTEXT);
      }

      this.StudentEditor();
    }
    .width('100%').padding({ left: 16, right: 16 }).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private TutorSection() {
    Column({ space: 0 }) {
      SettingsToggleRow({
        title: '引导优先',
        description: '先提醒概念和下一步，再逐步讲解。',
        isEnabled: this.tutorGuidanceFirst(),
        onToggle: (enabled: boolean) => this.updateTutorSettings(enabled, this.directAnswerAllowed())
      });
      Divider().color(AppTheme.DIVIDER);
      SettingsToggleRow({
        title: '允许直接答案',
        description: '默认建议关闭；开启后小伴才会在规则允许时直接展示答案。',
        isEnabled: this.directAnswerAllowed(),
        onToggle: (enabled: boolean) => this.updateTutorSettings(this.tutorGuidanceFirst(), enabled)
      });
    }
    .width('100%').padding({ left: 16, right: 16 }).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private CloudPanel() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('家庭云端').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text(BackendSession.instance.isConnected()
            ? `已连接${BackendSession.instance.getDisplayName().length > 0 ? ' · ' + BackendSession.instance.getDisplayName() : ''}`
            : '未连接 · 本地作业仍可使用')
            .fontSize(12).fontColor(BackendSession.instance.isConnected() ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start);
        Text(this.cloudPanelOpen ? '⌃' : '⌄').fontSize(16).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%').constraintSize({ minHeight: 52 }).padding({ top: 12, bottom: 12 })
      .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.cloudPanelOpen ? '家庭云端，已展开，点击收起' : '家庭云端，点击展开高级连接设置')
      .onClick(() => this.cloudPanelOpen = !this.cloudPanelOpen);

      if (this.cloudPanelOpen) {
        Divider().color(AppTheme.DIVIDER);
        Text('高级连接设置').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '例如 http://192.168.1.10:8080', text: this.baseUrl })
          .width('100%').height(AppTheme.INPUT_HEIGHT).backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS).onChange((value: string) => this.baseUrl = value);

        if (!BackendSession.instance.isConnected()) {
          TextInput({ placeholder: '家长账号', text: this.loginName }).width('100%').height(AppTheme.INPUT_HEIGHT)
            .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.loginName = value);
          TextInput({ placeholder: '密码', text: this.password }).width('100%').height(AppTheme.INPUT_HEIGHT)
            .type(InputType.Password).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.password = value);
          Button(this.connecting ? '正在连接…' : '连接并同步', { type: ButtonType.Normal }).width('100%')
            .height(AppTheme.BUTTON_HEIGHT).borderRadius(AppTheme.CONTROL_RADIUS).enabled(!this.connecting)
            .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.connect(); });
        } else {
          Row({ space: 8 }) {
            Button('立即同步', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
              .onClick(() => { void this.refreshStudents(); HomeworkSyncService.instance.requestSync(); });
            Button('断开连接', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
              .onClick(() => { void this.disconnect(); });
          }
          .width('100%');
        }
      }
    }
    .width('100%').padding({ left: 16, right: 16, bottom: 12 })
    .backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column({ space: 20 }) {
            Column({ space: 4 }) {
              Text('我的').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Text('管理家庭成员、小伴规则和数据同步。').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%').alignItems(HorizontalAlign.Start);

            Column({ space: 10 }) {
              this.SectionTitle('家庭', '孩子资料和教材信息');
              this.FamilySection();
            }
            .width('100%');

            Column({ space: 10 }) {
              this.SectionTitle('AI 辅导规则', '规则由家长设置，并应用到孩子下一次向小伴提问。');
              this.TutorSection();
            }
            .width('100%');

            Column({ space: 10 }) {
              this.SectionTitle('数据与同步', '普通使用无需修改服务地址；只有自建家庭云端时才需要进入高级设置。');
              this.CloudPanel();
            }
            .width('100%');

            if (this.message.length > 0) {
              Text(this.message).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT)
                .padding(12).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: AppTheme.SETTINGS_READABLE_MAX_WIDTH })
          .padding(AppTheme.PAGE_PADDING);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
