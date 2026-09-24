# 小伴作业 V2｜Phone / PAD 页面容器与卡片布局规范

> 状态：Active  
> 适用范围：HarmonyOS Phone / PAD 全部 V2 页面、组件、Dialog、Bottom Sheet  
> 配套规范：`v2-typography-standard.md`、`v2-phone-pad-baseline-standard.md`

## 1. 核心原则

- 字体由语义决定，卡片宽度由内容容器决定，动态内容高度由内容自然撑开。
- 不按设备型号或物理分辨率判断布局，只使用实际可用 vp 宽度。
- Feature 不新增页面私有的 900 / 1000 / 1080 / 1120 / 1400 等最大宽度。
- PAD 的目标不是把 Phone 卡片无限拉宽，而是通过 Grid、Master-Detail、双栏提升空间利用率。
- 普通业务卡片 `width('100%')` 表示占满当前内容列，不表示占满整个 PAD 屏幕。

## 2. 响应式区间

| 可用宽度 | 项目定义 | 页面左右边距 | 默认组合 |
|---|---|---:|---|
| <= 600vp | Compact | 16vp | 单列 |
| 601-840vp | Medium | 24vp | 单列 / 局部双列 |
| > 840vp | Expanded | 32vp | 多列 / Master-Detail |

统一入口：`LayoutPolicy.pagePaddingForWidth()`。

Feature 需要多栏时仍使用 `LayoutPolicy.canSplit(requirement)`，不能直接把上述区间当业务断点。

## 3. 内容容器宽度

统一为三级：

| Token | 宽度 | 场景 |
|---|---:|---|
| `CONTENT_NARROW_MAX_WIDTH` | 760vp | 长文本、窄表单、特殊阅读面 |
| `CONTENT_STANDARD_MAX_WIDTH` | 1040vp | 普通列表、练习、个人中心、设置、导入/创建 |
| `CONTENT_WIDE_MAX_WIDTH` | 1360vp | Dashboard、Master-Detail、双栏工作区 |

普通业务页面默认使用 Standard。Wide 只能用于真正存在多列或 Pane 组合的页面。

## 4. 页面边距

统一 token：

- `PAGE_PADDING_COMPACT = 16`
- `PAGE_PADDING_MEDIUM = 24`
- `PAGE_PADDING_EXPANDED = 32`

新代码不得再为页面创建私有左右边距。

## 5. 卡片规格

### 普通内容卡

- 宽度：当前内容列的 100%
- 高度：Auto
- Compact padding：`CARD_PADDING_COMPACT = 14`
- Standard padding：`CARD_PADDING_STANDARD = 18`
- Compact radius：`CARD_RADIUS_COMPACT = 16`
- Standard radius：`CARD_RADIUS_STANDARD = 20`

动态文本卡片禁止通过固定 `height` 保持视觉一致，应使用 `minHeight` + 文本溢出策略。

### 常见最小高度

- Assignment 列表项：78vp
- 家长首页操作卡：132vp
- Button：48vp
- Secondary Button：44vp
- Input：48vp

业务确有更复杂内容时可以自然增高。

## 6. 间距体系

布局新增值优先从以下刻度选择：

`4 / 8 / 12 / 16 / 20 / 24 / 32`

推荐：

- 卡片之间：12-16vp
- 卡片内部元素：8-12vp
- Section 之间：20-24vp
- 双栏 Pane：约 20vp
- 标题与正文：8vp

不得为了局部视觉微调持续新增 13 / 15 / 17 / 18 / 22 等缺乏稳定语义的值。

## 7. PAD 规则

PAD 优先顺序：

1. 保证 Standard 内容宽度一致；
2. 普通阅读内容不无限拉宽；
3. 有独立业务块时增加 Grid 列数；
4. 有主从关系时使用 Master-Detail；
5. 有工作区关系时使用双栏。

禁止只通过增加 `maxWidth` 解决 PAD 两侧空白。

## 8. 当前迁移策略

第一阶段：

- 建立共享三档宽度；
- 页面主体统一到 Standard / Wide；
- 修复失效和重复的页面宽度 token；
- 统一基础页面边距；
- 保留旧 feature token 作为兼容别名，避免一次性大范围回归。

第二阶段：

- 去除 `PHONE_*` 在宽屏页面中的语义污染；
- 收敛卡片 padding / radius / gap magic number；
- Practice / Profile / Settings / Voice Material 按需要增加 PAD Grid 或双栏。

第三阶段：

- 删除不再使用的旧 feature width alias；
- 增加静态检查，阻止新私有 width token 和无语义 magic number。

## 9. 验收

- 同一级页面切换时主体左右边界基本一致；
- Phone 紧凑宽度无横向溢出；
- PAD 普通页面主体默认不超过 1040vp；
- Master-Detail / Dashboard 默认不超过 1360vp；
- 页面不存在新增的私有 900 / 1000 / 1080 / 1120 / 1400 最大宽度；
- 动态文本卡片不通过固定高度压缩字体；
- PAD 两侧空白明显时优先评估多栏，而不是继续拉宽单卡。
