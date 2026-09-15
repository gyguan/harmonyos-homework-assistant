import { AppTheme } from '../../../common/theme/AppTheme';
import { BackendAuthService } from '../../../application/remote/BackendAuthService';
import { BackendSession } from '../../../application/remote/BackendSession';
import { FamilyCloudService } from '../../../application/remote/FamilyCloudService';
import { HomeworkSyncService } from '../../../application/remote/HomeworkSyncService';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { StudentProfile } from '../../../domain/model/HomeworkModels';

@Component
export struct BackendConnectionPage {
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
  onStoreChanged: () => void = () => {};

  aboutToAppear(): void {
    this.baseUrl = BackendSession.instance.getBaseUrl();
    if (BackendSession.instance.isConnected()) {
      void this.refreshStudents();
    }
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

  private toggleGuidanceFirst(): void {
    this.updateTutorSettings(!this.tutorGuidanceFirst(), this.directAnswerAllowed());
  }

  private toggleDirectAnswer(): void {
    this.updateTutorSettings(this.tutorGuidanceFirst(), !this.directAnswerAllowed());
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
    this.editingId = `student-${Date.now()}`;
    this.editName = '';
    this.editGrade = '';
    this.editClassName = '';
    this.editSemester = '上学期';
    this.editTextbooks = '';
  }

  private beginEdit(student: StudentProfile): void {
    this.editingId = student.id;
    this.editName = student.name;
    this.editGrade = student.grade;
    this.editClassName = student.className;
    this.editSemester = student.semester;
    this.editTextbooks = student.textbookSummary;
  }

  private cancelEdit(): void { this.editingId = ''; }

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
      this.pageRevision++;
      this.message = '孩子资料已删除';
      this.onStoreChanged();
    } else {
      this.message = '删除失败：已有作业的孩子或家庭最后一个孩子不能直接删除';
    }
  }

  private async disconnect(): Promise<void> {
    await BackendAuthService.instance.logout();
    this.message = '已断开云端连接，本地作业仍可继续使用';
    this.pageRevision++;
  }

  @Builder
  private StudentEditor() {
    if (this.editingId.length > 0) {
      Column({ space: 10 }) {
        Text('孩子资料').width('100%').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        TextInput({ placeholder: '姓名', text: this.editName }).width('100%').height(AppTheme.INPUT_HEIGHT)
          .onChange((value: string) => this.editName = value);
        Row({ space: 8 }) {
          TextInput({ placeholder: '年级，如 三年级', text: this.editGrade }).layoutWeight(1).height(AppTheme.INPUT_HEIGHT)
            .onChange((value: string) => this.editGrade = value);
          TextInput({ placeholder: '班级，如 三（2）班', text: this.editClassName }).layoutWeight(1).height(AppTheme.INPUT_HEIGHT)
            .onChange((value: string) => this.editClassName = value);
        }.width('100%');
        TextInput({ placeholder: '学期', text: this.editSemester }).width('100%').height(AppTheme.INPUT_HEIGHT)
          .onChange((value: string) => this.editSemester = value);
        TextArea({ placeholder: '教材版本，如 语文部编版 · 数学北师大版', text: this.editTextbooks })
          .width('100%').height(86).onChange((value: string) => this.editTextbooks = value);
        Row({ space: 8 }) {
          Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT).onClick(() => this.cancelEdit());
          Button('保存', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY).onClick(() => { void this.saveStudent(); });
        }.width('100%');
      }.width('100%').padding(14).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private TutorRule(title: string, description: string, enabled: boolean, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(description).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      Button(enabled ? '已开启' : '已关闭', { type: ButtonType.Normal })
        .height(36)
        .padding({ left: 13, right: 13 })
        .borderRadius(AppTheme.CHIP_RADIUS)
        .backgroundColor(enabled ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
        .fontColor(enabled ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
        .onClick(action);
    }.width('100%').padding({ top: 5, bottom: 5 });
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('我的').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('管理家庭云端连接、孩子资料和 AI 辅导规则。老师原文解析中间态仍只保留在本机。').fontSize(AppTheme.BODY_SIZE).fontColor(AppTheme.SUBTEXT);
        }.width('100%').alignItems(HorizontalAlign.Start);

        Column({ space: 12 }) {
          Text('家庭云端').width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          TextInput({ placeholder: '例如 http://192.168.1.10:8080', text: this.baseUrl })
            .width('100%').height(AppTheme.INPUT_HEIGHT).onChange((value: string) => this.baseUrl = value);
          if (!BackendSession.instance.isConnected()) {
            TextInput({ placeholder: '家长账号', text: this.loginName }).width('100%').height(AppTheme.INPUT_HEIGHT)
              .onChange((value: string) => this.loginName = value);
            TextInput({ placeholder: '密码', text: this.password }).width('100%').height(AppTheme.INPUT_HEIGHT).type(InputType.Password)
              .onChange((value: string) => this.password = value);
            Button(this.connecting ? '正在连接…' : '连接并同步', { type: ButtonType.Normal })
              .width('100%').height(AppTheme.BUTTON_HEIGHT).borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.connecting).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => { void this.connect(); });
          } else {
            Text(`已连接${BackendSession.instance.getDisplayName().length > 0 ? ' · ' + BackendSession.instance.getDisplayName() : ''}`)
              .width('100%').fontSize(13).fontColor(AppTheme.SUCCESS);
            Row({ space: 8 }) {
              Button('立即同步', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
                .onClick(() => { void this.refreshStudents(); HomeworkSyncService.instance.requestSync(); });
              Button('断开连接', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
                .onClick(() => { void this.disconnect(); });
            }.width('100%');
          }
          if (this.message.length > 0) {
            Text(this.message).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
          }
        }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);

        Column({ space: 10 }) {
          Text('AI 辅导规则').width('100%').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('家庭级规则会保存在本机，并用于孩子下一次向小伴提问。').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Divider().color(AppTheme.DIVIDER);
          this.TutorRule('引导优先', '先提醒概念和下一步，再逐步讲解。', this.tutorGuidanceFirst(),
            () => this.toggleGuidanceFirst());
          Divider().color(AppTheme.DIVIDER);
          this.TutorRule('允许直接答案', '默认建议关闭；开启后 Tutor 才能在规则允许时直接展示答案。', this.directAnswerAllowed(),
            () => this.toggleDirectAnswer());
        }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);

        Column({ space: 12 }) {
          Row() {
            Text('家庭成员').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Blank();
            if (BackendSession.instance.isConnected()) {
              Text('+ 新增孩子').fontSize(13).fontColor(AppTheme.PRIMARY).onClick(() => this.beginAdd());
            }
          }.width('100%');
          ForEach(this.students(), (student: StudentProfile) => {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(student.name).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
                Text(`${student.grade} · ${student.className} · ${student.semester}`).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
              }.layoutWeight(1).alignItems(HorizontalAlign.Start);
              if (BackendSession.instance.isConnected()) {
                Text('编辑').fontSize(13).fontColor(AppTheme.PRIMARY).onClick(() => this.beginEdit(student));
                Text('删除').fontSize(13).fontColor(AppTheme.DANGER).onClick(() => { void this.deleteStudent(student.id); });
              }
            }.width('100%').padding({ top: 10, bottom: 10 });
            Divider().color(AppTheme.DIVIDER);
          }, (student: StudentProfile) => student.id);
          this.StudentEditor();
          if (!BackendSession.instance.isConnected()) {
            Text('连接家庭云端后可新增、编辑或删除孩子。').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
        }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);
      }.width('100%').padding(AppTheme.PAGE_PADDING);
    }.width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
