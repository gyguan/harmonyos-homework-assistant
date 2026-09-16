# 小伴作业 V2｜Pad 原型一致性规范

> 状态：Active  
> 原型来源：`ui-page-spec-v2.md` + `ADR-0001`  
> 当前覆盖：Student Home、Assignment List/Detail、Study Workspace/Tutor

## 1. 核心原则

Pad 不是放大的 Phone。

V2 页面先满足 Phone 单列流程；当**当前 Feature 内容容器**能够同时满足各 pane 的最小可读宽度时，Pad/宽屏必须切换成原型规定的信息组合，而不是只做 `maxWidth + 居中`。

组合条件统一由 `LayoutPolicy` 基于真实容器宽度判断。禁止通过设备型号、Preview 特判或 Feature 私有 600/840/1080 断点选择布局。

## 2. Student Home

### Phone / 窄窗

保持 Focus Journey 单列：

```text
Header
TodayProgress
Attention?
NextAssignmentHero
RemainingAssignments
```

### Pad / 宽容器

```text
┌──────────────────────────────┬──────────────────┐
│ Header                       │ Attention?       │
│ TodayProgress                │                  │
│                              │ 今天还要做       │
│ NextAssignmentHero           │ Remaining...     │
│                              │                  │
└──────────────────────────────┴──────────────────┘
```

要求：

- 左侧 Hero 仍是第一视觉焦点，不被压缩成窄卡片；
- 右侧承载剩余任务/提醒摘要；
- 任一 pane 不满足最小宽度时立即回退单列；
- Pad 组合由 `LayoutPolicy.homeFocusSummaryRequirement()` 决定。

## 3. Assignment List + Detail

### Phone / 窄窗

```text
Assignment List
  -> 点击
NavDestination Assignment Detail
```

### Pad / 宽容器

```text
┌─────────────────────┬────────────────────────────────┐
│ Filter + List       │ Assignment Detail              │
│                     │                                │
│ selected item       │ instruction / timing / book    │
│                     │                                │
│                     │ [开始/继续/去提交]             │
└─────────────────────┴────────────────────────────────┘
```

要求：

- `selectedAssignmentId` 只属于 Assignment Feature 局部 UI 状态，不进入 AppShell；
- Phone 与 Pad 复用同一个 `AssignmentDetailPane`，不建立第二套业务详情模型；
- Pad 点击列表只切换右侧详情，不 push 新详情页；
- Pad 右侧详情里的主动作仍进入现有 Study NavDestination；
- 容器不足时恢复 Phone 的列表 -> 独立详情流程；
- 组合由 `LayoutPolicy.assignmentMasterDetailRequirement()` 决定。

## 4. Study Workspace + Tutor

### Phone / 窄窗

保持当前单任务沉浸式流程：

```text
Study content
[问小伴] [主动作]

问小伴 -> Tutor 独立子表面
```

### Pad / 宽容器

```text
┌────────────────────────────────┬──────────────────────┐
│ 当前学习内容                   │ AI 小伴              │
│ instruction / timer / resource │ messages             │
│ submission                     │ capture / composer   │
│                                │                      │
│ [主动作]                       │ [发送]               │
└────────────────────────────────┴──────────────────────┘
```

要求：

- Tutor 在宽屏中常驻右侧，不再通过“问小伴”按钮替换整张学习页；
- Study 主动作仍固定在学习 pane 底部；
- Tutor unavailable 不遮挡学习内容和提交；
- 窄窗自动退回 Phone 的 Tutor 子表面；
- 组合由 `LayoutPolicy.studyTutorRequirement()` 决定。

## 5. 当前不做

本轮只补齐已经重构学生页面与 V2 原型的 Pad 组合，不提前扩大到：

- Study 三栏 `今日任务 | 当前学习内容 | AI 小伴`；
- Parent Progress + Review master-detail；
- Import 原文 + Candidate 双栏；
- EXTRA Calendar 宽屏增强。

这些仍按后续 Slice 演进，但必须继续遵守同一 LayoutPolicy 原则。

## 6. 验收

人工 DevEco 验收至少覆盖：

- Phone 竖屏：三块页面保持原单列流程；
- Pad 竖屏/横屏：当内容宽度满足 requirement 时出现对应双区/双栏；
- Pad 分屏或窄窗：自动退回 Phone 组合；
- Assignment：左侧选择不同作业，右侧详情同步切换，主动作可进入 Study；
- Study：宽屏同时可见学习内容与 Tutor，窄屏 Tutor 仍是独立子表面；
- 不出现横向溢出、双滚动条或被压缩到不可读的 pane。
