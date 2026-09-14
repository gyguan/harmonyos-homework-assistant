# UI Prototype V1

> THROWAWAY PROTOTYPE — 用于回答“这个 App 应该长什么样”，不是生产代码。

本原型遵循 `mattpocock/skills` 的 `prototype` UI 流程：同一个原型内提供 3 个结构差异明显的 Variant，并通过 `?variant=` 切换。

## 设计问题

在已经确定产品闭环的前提下，学生端与家长端在 Phone / Pad 上应采用什么主要交互结构，尤其是学生的“学习工作台 + AI Tutor”如何成为核心体验？

## Variants

### A — Focus Journey

- 核心思想：学生每天只关注下一项作业。
- Phone：今日进度 + 单列任务。
- Pad：左侧导航 + 任务/详情主从分栏。
- 优点：简单、稳定、学习成本低。

### B — Learning Desk

- 核心思想：把 Pad 设计成真正的学习桌面。
- Pad：今日任务 / 当前作业 / AI Tutor 三栏同屏。
- Phone：退化成单列阅读与操作。
- 优点：最能体现 Pad 与 AI 辅导的产品差异化。

### C — Mission Board

- 核心思想：更适合小学生的任务卡与即时行动。
- 强调任务完成感和“问小伴”入口。
- 家长侧仍保持克制，不做游戏化。
- 优点：儿童友好、行动感强。

## 使用方式

打开 `index.html` 后，底部原型控制条可切换：

- Variant A / B / C
- 学生 / 家长
- Phone / Pad
- 当前页面

也可通过 URL 参数分享特定状态：

`index.html?variant=B&role=student&device=pad&page=study`

## 重点评审路径

1. `B + student + pad + study`：Pad 学习工作台。
2. `A + student + phone + today`：学生日常入口。
3. `A + parent + pad + import`：老师内容导入与 AI 解析。
4. `C + student + phone + today`：更儿童化的学生首页。

## 原型结论记录

选型后不要把三个 Variant 直接作为生产代码合入 main。应把最终选择和原因记录在 Issue #1，再基于选定方向重写正式 ArkUI 页面。