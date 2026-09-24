# 小伴作业 V2｜深层页面统一视觉与布局规范

> 状态：Active  
> 适用范围：V2 已重构及后续重构的二级/深层页面  
> 首批适配：Assignment Detail、Study Workspace  

## 1. 目标

V2 页面不再由各 Feature 私自实现返回按钮、标题栏和顶部留白。深层页面需要呈现为同一产品体系：返回方式一致、标题层级一致、顶部密度一致、内容从页面顶部自然开始。

本规范解决以下问题：

- 不同详情页返回图标、返回文字和触控区域不一致；
- 页面顶部重复 padding / header 导致大块空白；
- 详情、学习、Tutor、Submission 等页面标题层级不统一；
- 短内容因为全高容器默认布局而出现视觉上的上下居中；
- 长内容使用页面级 Scroll 时暴露系统滚动条，破坏页面视觉一致性；
- 后续页面重构时重复造一套 page header。

## 2. 页面分层

### 2.1 一级页面

包括：

- 学生首页；
- 作业列表；
- 我的；
- 家长首页等一级 Tab / SideNav 页面。

一级页面可以保留自身业务标题，不强制显示返回按钮。

### 2.2 深层页面

包括：

- Assignment Detail；
- Study Workspace；
- Tutor 独立页 / 全屏子表面；
- Submission；
- Resource / Textbook Detail；
- Parent Review 等从一级页面进入的详情或工作页。

深层页面必须复用 `DeepPageHeader`，禁止页面私自实现另一套返回图标或标题栏。

## 3. DeepPageHeader 规范

统一结构参考 HarmonyOS 系统“文件管理”进入文件夹后的 TitleBar：

```text
(‹)  页面标题 / 可选副标题                         可选右侧信息
```

其中返回入口采用浅色圆形容器 + 标准系统左箭头 Symbol，而不是裸字符或“返回”文字链接。

规则：

1. 返回区域固定使用至少 `MIN_TOUCH_TARGET` 的触控面积，并使用圆形浅色容器表达可点击性；
2. 返回图标统一使用 HarmonyOS Symbol `sys.symbol.chevron_left`，字号和颜色通过 `AppTheme` 统一；
3. 主标题固定使用 `PAGE_NAV_TITLE_SIZE`，与返回控件垂直居中；
4. 副标题和右侧 metadata 使用 `META_SIZE`；
5. 页面不得使用 `‹ 作业列表`、`返回学习任务` 等私有视觉写法作为 header；语义通过 accessibilityText 表达；
6. 页面可根据当前子状态修改标题，例如 Study Workspace 内进入 Tutor 时标题由“学习空间”变为“问小伴”，但仍复用同一个 Header；
7. 系统返回和 Header 返回必须保持同一 Navigation stack 语义。

## 4. 顶部留白与内容节奏

字体层级统一遵循 `v2-typography-standard.md`，深层页面结构统一使用 `AppTheme` chrome token：

- `DEEP_PAGE_TOP_PADDING = 8`
- `DEEP_PAGE_HEADER_HEIGHT = 48`
- `DEEP_PAGE_CONTENT_GAP = 12`
- `DEEP_PAGE_BOTTOM_PADDING = 24`

要求：

- Safe Area / NavDestination / 页面容器只允许一层承担顶部安全空间，Feature 页面不得再叠加大块 top padding；
- Header 下方内容应在一个标准 gap 后直接开始；
- 不为了“视觉居中”给短内容增加额外顶部空间；
- 深层页面主体始终 top anchored；全高 `Column` / `Scroll` 必须显式使用 `FlexAlign.Start` / `Alignment.TopStart`，不能依赖默认布局；
- 页面级纵向 Scroll 保留滚动能力，但默认隐藏系统滚动条（`scrollBar(BarState.Off)`）；只有滚动位置本身是重要导航信息时才例外；
- Phone 与 Pad 可以采用不同水平可读宽度，但顶部 chrome 不因设备型号而变化。

## 5. 内容宽度

统一的是 chrome 和垂直节奏，不强制所有深层页面具有同一个 maxWidth：

- 阅读型详情页可使用较窄内容宽度；
- Study Workspace 可以保留更宽的工作区；
- 是否多栏仍遵循 V2 Layout Capability，不通过设备名称或 Feature 私有断点决定。

## 6. 首批整改范围

本规范落地时优先整改已经完成 V2 重构的深层页面：

1. `StudentAssignmentDetailPage`
2. `StudyWorkspacePage`

一级页面如 Student Home / Assignment List 不增加无意义的返回 Header，只检查其顶部布局不与本规范冲突。

后续进入 V2 重构的 Tutor、Submission、Resource Detail、Parent Review 等页面，在切换到 V2 的同一 PR 中完成 Header 迁移，不新增临时视觉兼容层。

## 7. 工程约束

- 公共组件：`entry/src/main/ets/components/navigation/DeepPageHeader.ets`
- 样式 token：`AppTheme.DEEP_PAGE_*`
- 新深层页面不得声明私有 `WorkspaceHeader` / `DetailHeader` / `BackHeader` 来重复实现返回 chrome；
- 新深层页面不得直接绘制 `Text('‹')` 或其他裸字符作为页面返回入口；
- 返回图标必须使用公共 Header 中的 `SymbolGlyph($r('sys.symbol.chevron_left'))`；
- 页面级纵向 `Scroll` 必须 top anchored，默认关闭可见滚动条；
- 深层页面 UI 变更必须保持 Navigation / NavPathStack 的返回语义，不恢复 AppShell returnRoute / selectedId 状态；
- CI 的 V2 deep-page chrome gate 用于防止规范回退。

## 8. 验收标准

一个深层页面视为符合规范，需要同时满足：

- 使用 `DeepPageHeader`；
- 返回入口为系统化的圆形浅色按钮 + HarmonyOS 左箭头 Symbol；
- 返回触控区与视觉样式一致；
- 顶部只保留统一的紧凑留白；
- 内容 top anchored，短内容不得出现上下居中；
- 长内容可以自然滚动，但页面级系统滚动条默认不可见；
- 标题、metadata 字号来自 AppTheme token；
- 不存在 Feature 私有返回 glyph/header；
- Phone / Pad 页面 chrome 一致；
- 系统返回与页面返回到达同一上一级页面。
