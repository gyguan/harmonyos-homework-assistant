# ADR-0001: Phone / Pad UI 组合策略

- Status: Accepted
- Date: 2026-09-14

## Context

UI Prototype V1 提供了三个方向：

- A / Focus Journey：单任务聚焦、结构简单；
- B / Learning Desk：充分利用 Pad 宽屏，把任务、作业资料和 AI Tutor 同屏；
- C / Mission Board：更儿童友好的任务卡和文案。

产品必须同时服务 Phone 和 Pad，并保证学生端简单、家长端克制，同时让 Pad 具备独立价值。

## Decision

采用组合方案，而不是三选一：

1. **A 作为总体交互骨架**。
   - Phone 学生端以“下一项作业”为中心。
   - 家长端整体沿用 A 的克制结构。

2. **B 作为 Pad Study Workspace**。
   - Expanded 窗口下采用三栏：Today Task Rail / Study Content / AI Tutor。
   - Pad 导入页采用 Source / Candidate 双栏。

3. **C 只作为学生端视觉语言来源**。
   - 使用柔和卡片、学科识别、正向文案。
   - 不引入积分排行、强游戏化或奖励成瘾机制。

4. **响应按当前窗口宽度决定**，不按 Phone/Pad 型号判断。
   - Compact: <=600vp
   - Medium: 600–840vp
   - Expanded: >840vp

## Consequences

### Positive

- Phone 保持低认知负担。
- Pad 获得真正的大屏学习场景，而非放大手机 UI。
- 学生与家长视觉语言可区分，但共享组件和领域状态仍统一。
- 后续支持自由窗口、分屏时不需要重写设备判断。

### Cost

- Study Workspace 需要至少两套组合布局（Compact 与 Medium/Expanded）。
- 需要统一 responsive infrastructure，禁止页面各自判断断点。
- QA 必须覆盖 Phone、Pad 竖屏、Pad 横屏和分屏。

## Implementation guidance

V0.1 运行与编译基线为 HarmonyOS 6.0.0(20)，因此优先使用 API 20 可用的 `Navigation`、`NavPathStack`、`Row` / `Column`、`Grid` 与 `onAreaChange`，并通过统一 `ResponsiveContext` 管理窗口断点。

`ContainerReader` 当前官方文档标注为 API 26+，不属于 V0.1 可用实现能力。只有在未来提升最低 API，或确认存在 API 20 兼容替代方案后，才用于更细粒度的容器级响应式布局。

## Sources

- Product baseline: `docs/product/product-design-v1.md`
- UI direction: `docs/product/ui-design-v1.md`
- ArkUI page spec: `docs/product/arkui-page-spec-v1.md`
- Prototype primary source: branch `prototype/ui-v1`
