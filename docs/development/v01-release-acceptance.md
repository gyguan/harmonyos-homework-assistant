# 小伴作业 V0.1 发布验收清单

> 适用分支：`main`
>
> 目标：只验证 GitHub Actions 无法替代的真实 HarmonyOS 运行体验、局域网端云联调与真实 AI Provider。后端 PostgreSQL/Flyway/API 主链、409 乐观锁、Submission 图片鉴权、Tutor 无模型降级、Spring Boot 重启后 session 恢复已经由 CI 的 `backend-real-e2e` 自动验证，不需要每次在本地重复做。

## 0. 验收前准备

### 0.1 更新代码

PowerShell 单行：

```powershell
git checkout main; git pull origin main
```

### 0.2 本地依赖

- DevEco Studio 26.0.0；
- HarmonyOS SDK 6.0.0(20) / compile SDK 26.0.0；
- JDK 21；
- Maven 3.6.3+；
- Docker Desktop；
- Python 3.10+；
- Phone Emulator；
- Pad Emulator 或可调整到 `>840vp` 的大屏窗口。

### 0.3 验收原则

- 不修改 `modelVersion`、SDK 版本和 Hvigor 版本后再验收；
- 不把 `OPENAI_API_KEY`、Bearer token、`backend/.e2e-session.json` 上传到 GitHub、Issue 或聊天；
- 学生空间不能切换到家长或其他孩子；
- 老师原文 / Candidate 中间态仍应留在端侧；
- 只有发布后的 Assignment / Submission 进入家庭云端。

---

# 1. DevEco Build 与视觉验收（对应 #24）

## 1.1 Build

在 DevEco Studio 打开仓库根目录，选择 `entry` 模块并执行 Build。要求：

- Build 成功；
- 无新的 ArkTS 编译错误；
- Previewer / Emulator 可进入首页；
- 冷启动无白屏或崩溃。

## 1.2 Phone 验收

建议使用常规手机宽度。逐页检查：

| 页面 | 必看内容 | 通过标准 |
| --- | --- | --- |
| 人员入口 | 家长 + 每个孩子 | 卡片完整，无截断；选择人员后身份固定 |
| 学生·今天 | 完成度、下一项、任务卡 | 3 秒内能看出下一项；按钮不溢出 |
| 学生·作业 | 待处理/待开始/已提交/已完成 | 分区层级清楚；长标题可读 |
| 学生·学习 | 作业内容、计时、Tutor、提交 | 单栏顺序合理；底部操作不遮挡内容 |
| 学生·我的 | 学生资料、教材、Tutor 规则 | 只读；没有切换孩子/家长入口 |
| 家长·首页 | 完成情况、当前作业、异常/快捷入口 | 第一屏能看出今天状态 |
| 家长·导入 | 文字输入、截图 OCR、解析结果 | 输入区和按钮尺寸正常；错误提示可读 |
| 家长·确认 | Candidate、Source Evidence、编辑操作 | 编辑/删除/发布不拥挤 |
| 家长·进度 | 状态、Submission、照片、验收 | 缩略图与按钮不重叠 |
| 家长·我的 | 云端连接、孩子资料、Tutor 规则 | 表单输入和操作按钮完整可见 |

Phone 统一检查：

- 底部导航始终可见且不遮内容；
- 页面左右边距一致；
- 卡片圆角、字体层级、状态色一致；
- 无横向滚动、文本裁断、按钮高度异常；
- 键盘弹出后输入框仍可操作；
- 返回/切换页面不会丢失当前业务状态。

## 1.3 Pad / 宽屏验收

窗口宽度超过 `840vp` 后：

- AppShell 自动切换到左侧导航；
- 不出现手机底部导航与侧边导航同时存在；
- Study Workspace 能利用宽屏，而不是简单拉伸手机布局；
- Import / Confirmation 等宽屏页面的分栏关系自然；
- 左侧导航不压缩正文到不可读；
- 横竖屏/调整窗口大小后不出现布局断裂。

## 1.4 #24 关闭条件

以上 Phone + Pad 检查均通过后，#24 可关闭；发现视觉问题时只记录具体页面、窗口宽度和现象，不重新扩展产品功能范围。

---

# 2. HarmonyOS ↔ 家庭云端 E2E（对应 #28）

CI 已自动验证真实 PostgreSQL 后端，因此这里重点验证 **HarmonyOS App 到局域网 backend 的真实链路**。

## 2.1 启动 PostgreSQL

仓库根目录 PowerShell 单行：

```powershell
docker compose -f backend/docker-compose.yml up -d
```

## 2.2 启动 backend

仓库根目录 PowerShell 单行：

```powershell
cd backend; mvn spring-boot:run
```

默认开发账号：`parent / parent123`。

如果 Phone/Pad Emulator 不与 backend 在同一网络命名空间，不能填写 `localhost`。在 Windows 上执行 `ipconfig` 找到电脑当前局域网 IPv4，例如 `192.168.x.x`，App 中填写：

```text
http://<电脑局域网IPv4>:8080
```

## 2.3 家长连接与孩子资料

在 App 选择“家长” → “我的”：

1. 填写 backend 地址；
2. 使用开发账号登录；
3. 页面显示已连接；
4. 新增一个临时测试孩子；
5. 修改其班级/教材信息并保存；
6. 离开页面后重新进入，资料仍存在；
7. 冷启动 App 后 session 可自动恢复，不要求重新登录。

通过标准：App 的孩子资料与 backend 数据一致，学生入口可看到对应孩子。

## 2.4 作业跨端同步

以测试孩子为当前孩子：

1. 家长导入一段老师文字或截图；
2. 进入确认页，至少修改一个 Candidate 字段；
3. 发布作业；
4. 进入该孩子学生空间，Today / 作业页能看到新任务；
5. 开始任务，状态进入进行中；
6. 暂停后重新进入，计时可继续；
7. 标记完成并进入待提交；
8. 返回家长进度页，状态保持一致。

通过标准：Assignment 在端侧与云端状态一致；重新进入页面或重启 App 后状态不会回退。

## 2.5 真实照片提交与家长查看

学生进入待提交作业：

1. 从系统 PhotoPicker 选择 1～6 张真实图片；
2. 确认预览数量正确；
3. 提交；
4. 作业状态变为“已提交”；
5. 家长进入“进度”查看该 Submission；
6. 能看到云端 Submission 元数据和照片；
7. 家长执行“通过”或“需要重做”，学生端状态随之更新。

通过标准：照片不是 Mock；重新进入家长进度页仍能读取；图片读取通过已登录会话完成，不存在公开匿名图片 URL。

## 2.6 离线行为

在 App 已同步出至少一条作业后，临时停止 backend 或关闭设备网络：

- 学生仍能查看本地已有作业；
- Today / 作业 / 我的不因为无网变成空数据；
- 本地作业状态与 Preferences 快照仍可恢复；
- Tutor 明确提示不可用/未连接，而不是阻断作业主流程；
- 恢复网络后执行同步，不应静默覆盖较新的服务端版本。

## 2.7 #28 关闭条件

2.3～2.6 全部通过即可关闭 #28。PostgreSQL/Flyway、API 409、服务端 Submission、Bearer 图片鉴权等无需再人工重复，因为 `backend-real-e2e` 已自动覆盖。

---

# 3. 真实 AI Tutor E2E（对应 #30）

## 3.1 无模型配置

这一项已经由 CI 自动验证，不需要本地重复作为发布门禁。预期行为是：Tutor 明确显示模型未配置/暂不可用，但作业查看、完成、提交全部正常。

## 3.2 配置真实 Provider

不要把 Key 写进仓库。PowerShell 单行示例：

```powershell
$env:OPENAI_API_KEY="你的Key"; $env:OPENAI_MODEL="你的可用模型"; cd backend; mvn spring-boot:run
```

如果使用 OpenAI-compatible 服务，也可以通过本地环境或 `backend/config/application-local.yml` 设置 `AI_BASE_URL` / `AI_PROTOCOL` / `AI_TUTOR_MODEL`。`application-local.yml` 已被 `.gitignore` 排除。

## 3.3 先跑服务端真实模型 Smoke

backend 启动后，在仓库根目录 PowerShell 单行：

```powershell
python backend/scripts/e2e_smoke.py --expect-tutor-available
```

通过标准：结尾出现 `BACKEND_E2E_SMOKE_PASS`，且 Tutor 返回 `available=true` 与至少一条 assistant 消息。

## 3.4 再跑 HarmonyOS Tutor 体验

选择学生 → 打开一个真实云端 Assignment：

1. 点击“问小伴”；
2. 输入一个需要提示的问题；
3. Tutor 能返回消息；
4. 家长“我的”关闭“允许直接答案”，再次提问，行为仍以引导为主；
5. 开启“允许直接答案”后，新的请求使用最新规则；
6. 从拍题入口选择图片并 OCR，识别文本可带入 Tutor；
7. 退出 Study Workspace 后重新进入，同一作业对话历史仍能加载；
8. 切到另一个孩子/另一个 Assignment，不应看到前一条对话。

## 3.5 backend 重启恢复

服务端 token 跨重启已经由 CI 自动验证。App 侧只需补一项体验检查：

- 保持 PostgreSQL 不变，重启 backend；
- 再回到 App；
- 已保存 session 自动校验成功；
- 不需要重新输入账号密码；
- 原 Tutor 历史仍能读取。

## 3.6 #30 关闭条件

真实 Provider smoke + HarmonyOS Tutor 体验 + 对话隔离通过后即可关闭 #30。

---

# 4. V0.1 最终收口（对应 #1）

当且仅当：

- #24 DevEco Phone/Pad 视觉验收通过；
- #28 HarmonyOS ↔ 家庭云端 E2E 通过；
- #30 真实 AI Tutor E2E 通过；
- `main` 最新 GitHub Actions 全绿；

即可关闭 #1，作为 V0.1 MVP 基线完成标志。

建议最终只在 Issue 中记录 PASS/FAIL 和必要的失败现象，不上传 API Key、Bearer token、家庭真实作业照片或其他隐私数据。
