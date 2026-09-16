# ADR-0001: Phone / Pad UI 组合策略

- Status: Accepted / Updated for V2
- Original Date: 2026-09-14
- V2 Update: 2026-09-16

## Context

V1 原型曾探索 Focus Journey、Learning Desk 与儿童友好视觉三类方向。真实 Phone / Pad / Preview 验证后，V2 进一步明确：

- Phone 核心流程必须保持单列；
- Pad 的价值来自宽屏增强，不是放大 Phone；
- 分屏、自由窗口、折叠形态下，不能依赖设备型号决定业务布局；
- 业务多栏的真正条件是当前容器是否能同时满足各内容区的最小可读宽度；
- Window size class 可以继续服务 Shell 级导航，但不能直接决定 Feature 的单双栏。

## Decision

1. **Focus Journey 作为学生端主交互骨架。**
   - 学生首页以“下一项作业”为中心；
   - Phone 作业详情、学习空间、AI 小伴均可独立单页完成。

2. **Learning Desk 只作为宽屏增强模式。**
   - 作业页可组合“列表 + 详情”；
   - 学习空间可组合“学习内容 + AI 小伴”；
   - 家长进度可组合“列表 + 验收详情”；
   - 这些组合不是固定 Pad 布局，空间不足时必须退回单页导航。

3. **儿童友好视觉只作为表达语言，不引入强游戏化。**
   - 使用柔和卡片、学科标签、正向文案；
   - 不引入积分排行、PK、商城等机制。

4. **导航形态与业务内容布局分开判断。**
   - Shell 可以根据窗口能力选择底部导航 / 侧边导航；
   - Feature 页面不得把 `COMPACT / MEDIUM / EXPANDED` 直接等同于单栏 / 双栏 / 三栏。

5. **业务多栏使用容器能力判断。**

   多栏条件示意：

   ```text
   availableWidth >=
     primaryMinWidth +
     secondaryMinWidth +
     gap +
     horizontalPadding * 2
   ```

   这里的数值是内容最小可读宽度，不是设备断点。不同组合可以有不同的内容最小宽度，但必须通过统一 Layout Capability / LayoutPolicy 表达，不能散落在 Feature 页面。

6. **Phone 产品规则优先。**
   - Phone 核心学习流程不使用固定左右分栏；
   - 列表点击进入独立详情页；
   - AI 小伴使用独立页面 / 抽屉；
   - 即使横屏，也不能为了“看起来像 Pad”强制压缩成双栏。

## Consequences

### Positive

- Phone 不再因宽度识别异常进入 Pad 布局；
- Pad 只有真正有空间时才启用多栏；
- 分屏、自由窗口自然降级；
- 同一业务路由可以被 Phone / Pad 组合复用；
- 响应式逻辑从“设备分类”升级为“内容能力”。

### Cost

- 每种 master-detail / workspace 组合需要声明自己的最小宽度需求；
- QA 必须覆盖窄窗、Pad 竖屏、横屏和分屏；
- 旧页面中直接判断 `WindowSizeClass` 的布局逻辑需要随 V2 切片删除。

## Implementation guidance

当前运行与编译基线为 HarmonyOS 6.0.0(20)。

优先使用：

- `Navigation` / `NavPathStack` / `NavDestination`；
- `Row` / `Column` / `Grid`；
- `onAreaChange` 获取当前容器真实区域；
- 统一 `LayoutPolicy` / `LayoutCapability` 判断多栏能力。

当前不强制依赖 API 26+ 的 `ContainerReader`。未来最低 API 升级后，可以替换容器测量实现，但 Feature 页面仍只依赖统一 Layout Capability，不需要重写业务页面。

## Source of truth

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`
- `docs/README.md`

`docs/product/ui-design-v1.md` 仅为历史文档，不再是本 ADR 的现行实现来源。
