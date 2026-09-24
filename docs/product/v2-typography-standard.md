# 小伴作业 V2｜字体与文本布局规范

> 状态：Active  
> 适用范围：HarmonyOS Phone / Pad 全部 V2 页面、组件、Dialog、Bottom Sheet  
> 目标：建立稳定的语义字体层级，同时保证现有卡片、列表和触控区域不会因字号调整出现挤压、错位或溢出。

## 1. 设计依据

本规范参考 HarmonyOS 当前设计与 ArkUI 文本能力，但项目字号不是对官方数值的机械复制。

采用的官方原则：

- 优先使用系统默认字体体系，保持 HarmonyOS 原生一致性；
- 主标题、子标题、正文必须有明确层级；
- 子标题用于组织界面分区，应简洁、与主标题有明显层级差异；
- 文本溢出使用 `maxLines + textOverflow(Ellipsis)`；
- 受限布局可使用 `minFontSize / maxFontSize`，但必须结合 `maxLines` 或布局约束；
- 跨设备字号不能过小，布局适配优先通过容器能力和可读宽度完成，而不是维护 Phone / Pad 两套业务字号。

当前项目继续使用系统默认字体，不打包自定义字体文件。

## 2. 核心原则

### 2.1 字号由“语义”决定，不由页面决定

同一种信息角色只能使用同一个字体 token。

禁止：

- Phone 一套标题字号、Pad 另一套标题字号；
- 同为一级分区标题，A 页面 14、B 页面 17、C 页面 20；
- 为了让文本塞进固定卡片而随意缩小字号。

允许变化的是：

- 容器宽度；
- 单栏 / 多栏组合；
- 最大可读宽度；
- 文本最大行数；
- 卡片最小高度。

### 2.2 动态文本容器用 minHeight，不用固定 height

包含业务标题、姓名、作业名称、老师要求等动态文本的卡片，默认只能设置 `minHeight`。

固定 `height` 只用于：

- Button；
- TextInput；
- 导航栏；
- 图标容器；
- 其他内容高度完全可控的系统控件。

### 2.3 优先让容器增长，不优先缩字

业务标题过长时：

1. 首选允许 2 行；
2. 再使用省略号；
3. 卡片允许在 `minHeight` 基础上自然增长；
4. 不因为长标题把 16fp 临时改成 13fp。

`minFontSize / maxFontSize` 仅用于宽度真正固定、且文本语义允许视觉缩放的单行控件，不用于正文和普通卡片标题。

## 3. 项目字体层级

所有 token 位于：

`entry/src/main/ets/common/theme/AppTheme.ets`

| 语义角色 | Token | 字号 | 行高 | 默认字重 | 默认最大行数 | 典型场景 |
|---|---|---:|---:|---|---:|---|
| 业务对象主标题 | `PAGE_TITLE_SIZE` | 26 | 34 | Bold | 2 | 当前作业名、试卷名 |
| 页面导航标题 | `PAGE_NAV_TITLE_SIZE` | 20 | 28 | Medium | 1 | DeepPageHeader、Dialog、Sheet |
| 一级分区标题 | `SECTION_TITLE_SIZE` | 17 | 24 | Medium / Bold | 1 | 作业内容、任务设置、答题回顾 |
| 卡片/折叠项标题 | `CARD_TITLE_SIZE` | 16 | 22 | Medium | 2 | Assignment 卡片、我的折叠项 |
| 表单/筛选小标题 | `LABEL_TITLE_SIZE` | 14 | 20 | Medium | 1 | 日期、科目、来源、状态 |
| 正文 | `BODY_SIZE` | 14 | 21 | Normal | 自然换行 | 老师要求、说明 |
| 元信息 | `META_SIZE` | 13 | 18 | Normal / Medium | 1 | 截止时间、用时、状态辅助信息 |
| 辅助说明 | `CAPTION_SIZE` | 12 | 17 | Normal | 1-2 | 卡片副标题、说明 |
| 操作文案 | `ACTION_TEXT_SIZE` | 14 | 20 | Medium | 1 | 普通按钮、文本动作 |

特殊数字例如倒计时、分数、统计值属于 Data Emphasis，不套用标题层级；必须在具体组件中定义，并说明其用途。

## 4. Phone / Pad 规则

Phone 与 Pad 使用同一语义字号。

禁止重新引入：

- `PHONE_PAGE_TITLE_SIZE`
- `PHONE_SECTION_TITLE_SIZE`
- `PAD_PAGE_TITLE_SIZE`
- `PAD_SECTION_TITLE_SIZE`
- `PAD_CARD_TITLE_SIZE`

Pad 的增强通过以下方式实现：

- 更大的可读宽度；
- 多栏；
- 更充足的间距；
- 必要时正文密度优化。

不能通过把普通 16fp 卡片标题直接放大到 18/20fp 来制造 Pad 感。

## 5. 卡片尺寸兼容规范

### 5.1 家长首页操作卡

当前统一规格：

- `PARENT_HOME_ACTION_CARD_MIN_HEIGHT = 132`
- 图标容器 44 × 44；
- padding = 16；
- 标题 = 16 / 22；
- 副标题 = 12，推荐行高 17-18；
- Phone 三张卡同宽纵向排列；
- 宽屏三列等宽。

132 是最小高度，不是强制固定高度。

如果标题或系统字体缩放使内容需要更高空间，卡片可以自然增高，三个并排卡片由父布局保持同一行顶部对齐，不允许通过缩小其中一个标题字号维持高度。

### 5.2 Assignment 列表项

当前最小高度 78。

推荐：

- 标题 16 / 22，最多 2 行；
- metadata 12-13 / 18，最多 1 行；
- 超长 metadata 使用 ellipsis；
- 不增加固定文本高度。

### 5.3 普通内容卡

- padding 优先使用 `CARD_PADDING` / `PHONE_CARD_PADDING`；
- 标题最多 2 行；
- 正文自然换行；
- 不允许 `height(...) + 动态 Text` 的组合，除非明确证明文本永远单行。

## 6. 文本溢出策略

### 页面导航标题

```text
20 / 28
maxLines = 1
ellipsis
```

### 卡片标题

```text
16 / 22
maxLines = 2
ellipsis
card = minHeight
```

### 一级分区标题

默认单行。若产品文案超过一行，应优先缩短标题，而不是允许三级换行。

### 正文

正文不默认截断。老师要求、作业说明等业务内容应完整显示或进入明确的展开/详情交互。

## 7. 字重规范

- Bold：业务对象主标题、少量强主入口；
- Medium：页面标题、分区标题、卡片标题、按钮；
- Normal：正文、描述、metadata。

禁止通过同时“放大字号 + Bold + 强色”叠加三个强调手段，除非它是页面唯一主视觉。

## 8. 颜色规范

- 主标题 / 卡片标题：`AppTheme.TEXT`
- 正文：`AppTheme.TEXT`
- 描述 / metadata：`AppTheme.SUBTEXT`
- 弱提示：`AppTheme.TERTIARY_TEXT`
- 可点击文字：`AppTheme.PRIMARY`

字号层级不能依赖颜色来补救；颜色只提供第二层语义。

## 9. 新组件开发规则

新增 Text 前先判断其语义角色，再选 token。

禁止：

```ts
Text('标题').fontSize(15)
Text('标题').fontSize(18)
```

应使用：

```ts
Text('标题')
  .fontSize(AppTheme.CARD_TITLE_SIZE)
  .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
  .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
```

如果现有 token 无法表达需求，应先证明出现了新的稳定语义层级，再修改 Theme；不要在 Feature 中增加新的 magic number。

## 10. 迁移策略

不进行一次性“全局替换所有 fontSize 数字”。

原因：

- 数字可能是图标大小；
- 倒计时和分数属于数据强调；
- Button / Input 的字号和内容卡标题不是同一语义；
- 机械替换容易改变卡片高度和换行。

迁移顺序：

1. 页面 / Dialog / Sheet 标题；
2. 一级分区标题；
3. 卡片 / 列表标题；
4. 表单标签；
5. 正文 / metadata / caption；
6. 最后处理按钮和特殊数字。

每次迁移必须同时检查：

- Phone portrait；
- Pad；
- 窄窗；
- 长标题；
- 空状态；
- 字体放大场景。

## 11. 验收标准

字体相关 UI 变更合并前至少确认：

- 同语义标题使用同一 token；
- 没有恢复 Phone / Pad 私有标题 token；
- 动态文本卡片没有固定 height；
- 卡片标题最多 2 行并有明确溢出策略；
- 页面标题单行溢出安全；
- 字号变化后卡片允许自然增高；
- 并排卡片仍保持一致的布局节奏；
- 触控区域仍不低于项目统一最小值；
- 低于 12fp 的业务文本必须有明确例外理由；
- 不因为适配长文案临时缩小字号。

## 12. 参考

参考 HarmonyOS 官方资料：

- HarmonyOS Design / Design Guide；
- HarmonyOS Sans 设计资源；
- HarmonyOS 子标题设计指南；
- ArkUI Text 文本显示与自适应字体能力；
- HarmonyOS Cross-device App Dev 字号 Lint 规则。

本文件中的具体字号和行高是“小伴作业”基于现有 UI 尺寸制定的项目规范，不代表 HarmonyOS 官方固定字号表。
