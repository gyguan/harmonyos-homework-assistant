# 小伴作业 V2｜Phone / Pad 基础适配规范

> 状态：Active  
> 适用范围：所有已完成或后续进入 V2 重构的前端页面  
> 目标：先保证 Phone / Pad 都具备稳定、可读、可组合的基础体验，再按产品优先级建设完整 Pad 增强。

## 1. 基础适配与 Pad 增强必须分开

V2 不接受“Phone 页面直接横向放大到 Pad”，也不要求每个切片都立即完成复杂的 Pad 双栏。

### 基础适配：每个 V2 页面切换时必须完成

- Phone 在紧凑宽度下可正常使用，不横向溢出；
- 宽容器下限制内容最大可读宽度，避免卡片和正文无限拉伸；
- Dialog / Bottom Sheet 在宽容器下限制自身可读宽度；
- 页面滚动、顶部对齐、触控区域和 Deep Page Chrome 在 Phone / Pad 上保持一致；
- 字体语义层级遵循 `v2-typography-standard.md`，Phone / Pad 不维护两套标题字号；
- Feature 不判断 Phone / Pad 型号，不读取物理 display，不维护私有设备断点；
- Feature 不直接用 `WindowSizeClass.COMPACT / MEDIUM / EXPANDED` 决定业务组合、字号或密度；
- 需要多栏时，统一通过 `LayoutPolicy` 根据实际内容容器宽度和 pane 最小可读宽度决定。

### 完整 Pad 增强：可以按后续切片实施

包括但不限于：

- Assignment List + Detail master-detail；
- Pad 常驻筛选栏；
- Study + Tutor 双栏；
- Home 宽屏信息组合；
- Parent Progress + Review master-detail。

完整 Pad 增强可以延期，但基础适配不能延期。

## 2. 响应式职责边界

### Shell

Shell 可以使用共享 `WindowSizeClass` 决定：

- Bottom Navigation；
- Side Navigation；
- Shell 级上下文区。

窗口宽度来自真实容器 `onAreaChange`，不来自设备名称。

### Feature

Feature 只关心：

1. 当前内容容器是否保持单栏可读；
2. 当前内容容器是否满足某个明确的多栏能力。

Feature 不应写：

```text
if COMPACT -> A
if EXPANDED -> B
```

未来需要多栏时，应写成：

```text
availableWidth
  -> LayoutPolicy.canSplit(requirement)
  -> single composition / split composition
```

这里的 requirement 是内容最小可读宽度，不是设备断点。

## 3. LayoutPolicy

公共入口：

`entry/src/main/ets/common/responsive/LayoutPolicy.ets`

当前预留能力：

- `assignmentMasterDetailRequirement()`：Assignment List + Detail；
- `studyTutorRequirement()`：Study + Tutor。

`LayoutPolicy` 只计算：

```text
primaryMinWidth
+ secondaryMinWidth
+ gap
+ horizontalPadding * 2
```

它不识别 Phone、Pad、型号、Preview 或测试环境。

## 4. 单栏可读宽度

基础适配阶段，宽屏页面优先使用“居中 + 最大可读宽度”，而不是把 Phone 内容铺满整个 Pad。

统一 token 位于 `AppTheme`：

- `HOME_READABLE_MAX_WIDTH`
- `ASSIGNMENT_LIST_READABLE_MAX_WIDTH`
- `ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH`
- `STUDY_READABLE_MAX_WIDTH`
- `FILTER_DIALOG_MAX_WIDTH`

这些值属于内容可读性约束，不是设备断点。

## 5. 已重构页面当前基线

### Student Home

Phone：单列展示按优先级排序的今日任务，每项直接开始、继续或提交，不显示统计卡和学科折叠层。
Pad：空间足够时使用“先做这项 + 接下来”双区，否则回退 Phone 单列；所有内容保持可读宽度。

### Assignment List

Phone：单列列表 + Bottom Filter。  
Pad 基线：列表保持居中可读宽度；筛选弹层限制最大宽度。  
完整 Pad 增强：常驻筛选栏 + List/Detail master-detail 后续实现。

### Assignment Detail

Phone：独立详情页。  
Pad 基线：独立详情页保持较窄阅读宽度并居中。  
完整 Pad 增强：后续抽取可复用 `AssignmentDetailPane`，供 master-detail 组合使用。

### Study Workspace

Phone：单任务沉浸式单列，Tutor 作为独立子表面。  
Pad：默认将当前学习内容限制在可读宽度内；学生主动打开 Tutor 且满足 `studyTutorRequirement()` 后组合 Study + Tutor 双栏。

## 6. 新页面验收标准

V2 页面合并前至少满足：

- Phone 紧凑宽度无横向溢出；
- 宽容器内容不会无限拉伸；
- 弹层在 Pad 上不会无意义铺满整屏；
- Feature 内无设备身份判断；
- Feature 内无私有 600 / 840 / 1080 等设备式断点；
- 新 V2 Feature 不直接用 `WindowSizeClass` 决定业务布局；
- 需要 split 时使用 `LayoutPolicy` + 实际容器宽度；
- Deep Page 同时遵守 `v2-deep-page-chrome-standard.md`；
- 完整 Pad 增强若延期，应明确属于后续增强，而不是通过临时分支假装完成。
