# HarmonyOS Homework Assistant

面向深圳小学家庭的 HarmonyOS 6.0 作业辅导与进度管理应用。

## Product goals

- 对接深圳小学教材体系，并允许家庭/班级补充教材资料。
- 支持老师提供的视频、语音、图片和文档形成结构化作业。
- 支持将微信、钉钉中的作业通过主动分享、截图识别或文本粘贴转成作业清单。
- 学生完成后拍照/录音/视频提交，家长实时查看进度。
- Phone 与 Pad 同时作为一级设备形态设计，Pad 支持主从分栏、大屏看板和横竖屏/分屏窗口。

## Engineering workflow

本项目采用 Matt Pocock `skills` 的工程方法作为 Agent 辅助开发流程。安装与使用约定见 `docs/agents/matt-pocock-skills.md`，项目领域语言见 `CONTEXT.md`。

后续建议流程：需求澄清 → 规格化 → 领域建模/架构设计 → 原型 → TDD 实现 → Code Review。

## Current development baseline

- DevEco Studio / project model: 6.0.2
- HarmonyOS API baseline: 6.0.0(20) for compile / compatible / target
- Devices: Phone + Tablet
- UI: ArkTS + ArkUI, Stage model

### Static gate

在仓库根目录执行：

`python scripts/validate_harmony_project.py`

该 Gate 会检查 SDK 基线、Hvigor 插件、统一响应式断点、Phone/Tablet 声明、Navigation 根结构以及 API 26+ 能力误用等关键工程约束。

## Current implementation status

Issue #2 / PR #3 已完成工程骨架、首批四个 Mock 页面、响应式 Shell、失败态复现与静态 Gate。PR 仍保持 Draft，等待 DevEco Studio 本地编译、Previewer / 模拟器和软键盘 / 分屏验证后再进入合并评审。
