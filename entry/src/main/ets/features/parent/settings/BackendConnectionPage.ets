import { BackendAuthService } from '../../../application/remote/BackendAuthService';
import { BackendSession } from '../../../application/remote/BackendSession';
import { FamilyCloudService } from '../../../application/remote/FamilyCloudService';
import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { SettingsToggleRow } from '../../../components/selection/SelectionControls';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

@Component
export struct BackendConnectionPage {
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  @State private availableWidthVp: number = 390;
  @State private baseUrl: string = '';
  @State private loginName: string = 'parent';
  @State private password: string = '';
  @State private message: string = '';
  @State private connecting: boolean = false;
  @State private pageRevision: number = 0;
  @State private familyStudents: StudentProfile[] = [];
  @State private editingId: string = '';
  @State private editName: string = '';
  @State private editGrade: string = '';
  @State private editClassName: string = '';
  @State private editSemester: string = '';
  @State private editTextbooks: string = '';
  @State private familyExpanded: boolean = false;
  @State private parentAccessExpanded: boolean = false;
  @State private tutorRulesExpanded: boolean = false;
  @State private dataSyncExpanded: boolean = false;
  @State private parentAccessCodeDraft: string = '';
  @State private parentAccessCodeConfirm: string = '';
  @State private parentAccessMessage: string = '';
  @State private deleteStudentConfirmId: string = '';
  onStoreChanged: () => void = () => {};

  aboutToAppear(): void {
    this.baseUrl = BackendSession.instance.getBaseUrl();
    this.syncLocalStudents();
    if (BackendSession.instance.isConnected()) void this.refreshStudents();
  }

  private canInlineStudentFields(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.settingsInlineFieldsRequirement());
  }

  private syncLocalStudents(): void {
    this.familyStudents = this.familyContext.getStudents();
  }

  private students(): StudentProfile[] {
    let currentRevision = this.pageRevision;
    return this.familyStudents;
  }

  private parentAccessEnabled(): boolean {
    return this.familyContext.getSettings().parentAccessCode.length > 0;
  }

  private validParentAccessCode(value: string): boolean {
    if (value.length !== 4) return false;
    for (let i = 0; i < value.length; i++) {
      let code = value.charCodeAt(i);
      if (code < 48 || code > 57) return false;
    }
    return true;
  }

  private saveParentAccessCode(): void {
    let code = this.parentAccessCodeDraft.trim();
    if (!this.validParentAccessCode(code)) {
      this.parentAccessMessage = '家长码需要设置为 4 位数字';
      return;
    }
    if (code !== this.parentAccessCodeConfirm.trim()) {
      this.parentAccessMessage = '两次输入的家长码不一致';
      return;
    }
    this.familyContext.updateParentAccessCode(code);
    this.parentAccessCodeDraft = '';
    this.parentAccessCodeConfirm = '';
    this.parentAccessMessage = '家长码已启用';
    this.pageRevision++;
    this.onStoreChanged();
  }

  private clearParentAccessCode(): void {
    this.familyContext.updateParentAccessCode('');
    this.parentAccessCodeDraft = '';
    this.parentAccessCodeConfirm = '';
    this.parentAccessMessage = '家长码已关闭';
    this.pageRevision++;
    this.onStoreChanged();
  }

  private tutorGuidanceFirst(): boolean {
    let currentRevision = this.pageRevision;
    return this.familyContext.getSettings().tutorGuidanceFirst;
  }

  private directAnswerAllowed(): boolean {
    let currentRevision = this.pageRevision;
    return this.familyContext.getSettings().directAnswerAllowed;
  }

  private updateTutorSettings(guidanceFirst: boolean, directAnswerAllowed: boolean): void {
    this.familyContext.updateTutorSettings(guidanceFirst, directAnswerAllowed);
    this.pageRevision++;
    this.message = '';
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
      await BackendAuthService.instance.login(this.baseUrl, this.loginName, this.password);
      let familySynced = await FamilyCloudService.instance.syncStudents();
      let homeworkSynced = await DefaultAssignmentRepository.instance.refresh();
      this.syncLocalStudents();
      this.pageRevision++;
      this.message = familySynced && homeworkSynced ? '' : '已登录，部分数据稍后再同步';
      this.onStoreChanged();
    } catch {
      this.message = '连接失败，请检查电脑局域网地址、后端服务和账号密码';
    } finally {
      this.connecting = false;
    }
  }

  private async refreshStudents(): Promise<void> {
    if (await FamilyCloudService.instance.syncStudents()) {
      this.syncLocalStudents();
      this.pageRevision++;
      this.onStoreChanged();
    }
  }

  private async syncCloudData(): Promise<void> {
    let familySynced = await FamilyCloudService.instance.syncStudents();
    let homeworkSynced = await DefaultAssignmentRepository.instance.refresh();
    this.syncLocalStudents();
    this.pageRevision++;
    this.message = familySynced && homeworkSynced ? '' : '部分数据同步失败，请稍后重试';
    this.onStoreChanged();
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
      this.syncLocalStudents();
      this.pageRevision++;
      this.message = '';
      this.onStoreChanged();
    } else {
      this.message = '保存失败，请确认云端连接';
    }
  }

  private async deleteStudent(studentId: string): Promise<void> {
    if (await FamilyCloudService.instance.deleteStudent(studentId)) {
      this.editingId = '';
      this.deleteStudentConfirmId = '';
      this.syncLocalStudents();
      this.pageRevision++;
      this.message = '';
      this.onStoreChanged();
    } else {
      this.deleteStudentConfirmId = '';
      this.message = '删除失败：已有作业的孩子或家庭最后一个孩子不能直接删除';
    }
  }

  private async disconnect(): Promise<void> {
    await BackendAuthService.instance.logout();
    this.message = '';
    this.pageRevision++;
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
              .width('100%').fontSize(13).lineHeight(18).fontColor(AppTheme.SUBTEXT);
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
          CenteredTextBadge({
            badgeText: student.name.length > 0 ? student.name.substring(0, 1) : '伴',
            badgeWidth: 38,
            badgeHeight: 38,
            badgeFontSize: 15,
            badgeRadius: 12,
            badgeForeground: AppTheme.PRIMARY,
            badgeBackground: AppTheme.PRIMARY_SOFT
          });
          Column({ space: 3 }) {
            Text(student.name).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text(`${student.grade} · ${student.className} · ${student.semester}`).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start);
          Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%').constraintSize({ minHeight: 60 }).padding({ top: 12, bottom: 12 })
        .accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(`${student.name}，${student.grade}，${student.className}，编辑资料`)
        .onClick(() => this.beginEdit(student));
        Divider().color(AppTheme.DIVIDER);
      }, (student: StudentProfile) =>
        `${student.id}:${student.name}:${student.grade}:${student.className}:${student.semester}:${student.textbookSummary}`);

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
          .fontSize(13).fontColor(AppTheme.SUBTEXT);
      }

      this.StudentEditor();
    }
    .width('100%');
  }

  @Builder
  private ParentAccessSection() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('设备家长码')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(this.parentAccessEnabled() ?
            '已启用 · 学生切回家长模式时需要验证' :
            '未启用 · 可设置 4 位数字防止孩子误入家长操作')
            .fontSize(13)
            .lineHeight(18)
            .fontColor(this.parentAccessEnabled() ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      TextInput({ placeholder: '输入新的 4 位家长码', text: this.parentAccessCodeDraft })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .type(InputType.Password)
        .maxLength(4)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.parentAccessCodeDraft = value;
          this.parentAccessMessage = '';
        });

      TextInput({ placeholder: '再次输入家长码', text: this.parentAccessCodeConfirm })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .type(InputType.Password)
        .maxLength(4)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.parentAccessCodeConfirm = value;
          this.parentAccessMessage = '';
        });

      Row({ space: 8 }) {
        if (this.parentAccessEnabled()) {
          Button('关闭家长码', { type: ButtonType.Normal })
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .padding({ left: 16, right: 16 })
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .onClick(() => this.clearParentAccessCode());
        }
        Button(this.parentAccessEnabled() ? '修改家长码' : '启用家长码', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.saveParentAccessCode());
      }
      .width('100%');

      if (this.parentAccessMessage.length > 0) {
        Text(this.parentAccessMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(this.parentAccessMessage.indexOf('已') === 0 ? AppTheme.SUCCESS : AppTheme.DANGER);
      }

      Text('家长码只保存在当前设备，不会上传家庭云端。')
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%');
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
    .width('100%');
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
            .fontSize(13).fontColor(BackendSession.instance.isConnected() ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      Divider().color(AppTheme.DIVIDER);
      Text('高级连接设置').width('100%').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
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
            .onClick(() => { void this.syncCloudData(); });
          Button('断开连接', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
            .onClick(() => { void this.disconnect(); });
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private FamilySettingsSection() {
    Column({ space: 2 }) {
      Row() {
        Column({ space: 3 }) {
          Text('家庭')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('孩子资料和教材信息')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text(this.familyExpanded ? '收起' : '查看')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .alignItems(VerticalAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.familyExpanded ? '收起家庭资料' : '查看家庭资料')
      .onClick(() => this.familyExpanded = !this.familyExpanded);

      if (this.familyExpanded) {
        this.FamilySection();
      }
    }
    .width('100%')
    .padding(16);
  }

  @Builder
  private ParentAccessSettingsSection() {
    Column({ space: 2 }) {
      Row() {
        Column({ space: 3 }) {
          Text('家长保护')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('限制学生误进入家长操作')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text(this.parentAccessExpanded ? '收起' : '查看')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .alignItems(VerticalAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.parentAccessExpanded ? '收起家长保护' : '查看家长保护')
      .onClick(() => this.parentAccessExpanded = !this.parentAccessExpanded);

      if (this.parentAccessExpanded) {
        this.ParentAccessSection();
      }
    }
    .width('100%')
    .padding(16);
  }

  @Builder
  private TutorRulesSettingsSection() {
    Column({ space: 2 }) {
      Row() {
        Column({ space: 3 }) {
          Text('AI 辅导规则')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('设置小伴的讲解和答案规则')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text(this.tutorRulesExpanded ? '收起' : '查看')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .alignItems(VerticalAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.tutorRulesExpanded ? '收起 AI 辅导规则' : '查看 AI 辅导规则')
      .onClick(() => this.tutorRulesExpanded = !this.tutorRulesExpanded);

      if (this.tutorRulesExpanded) {
        this.TutorSection();
      }
    }
    .width('100%')
    .padding(16);
  }

  @Builder
  private DataSyncSettingsSection() {
    Column({ space: 2 }) {
      Row() {
        Column({ space: 3 }) {
          Text('数据与同步')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('家庭云端和数据同步')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text(this.dataSyncExpanded ? '收起' : '查看')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .alignItems(VerticalAlign.Center)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.dataSyncExpanded ? '收起数据与同步' : '查看数据与同步')
      .onClick(() => this.dataSyncExpanded = !this.dataSyncExpanded);

      if (this.dataSyncExpanded) {
        this.CloudPanel();
      }
    }
    .width('100%')
    .padding(16);
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column({ space: 18 }) {
            Column() {
              this.FamilySettingsSection();
              Divider().color(AppTheme.DIVIDER);
              this.ParentAccessSettingsSection();
              Divider().color(AppTheme.DIVIDER);
              this.TutorRulesSettingsSection();
              Divider().color(AppTheme.DIVIDER);
              this.DataSyncSettingsSection();
            }
            .width('100%')
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);

            if (this.message.length > 0) {
              Text(this.message).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT)
                .padding(12).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: AppTheme.PROFILE_READABLE_MAX_WIDTH })
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
