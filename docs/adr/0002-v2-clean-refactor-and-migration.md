# ADR-0002: V2 干净重构与迁移策略

- Status: Accepted
- Date: 2026-09-16

## Context

V1 已完成一轮真实前后端闭环，但 Phone / Pad UI 在持续演进过程中出现了典型的局部修补风险：

- 业务页面通过窗口 size class 推导单双栏，真实运行时与 Preview 差异导致反复修补；
- `AppShell` 同时承担角色、一级导航、业务路由、详情状态、返回路径、响应式与同步触发；
- `HomeworkStore` 同时承担本地数据、持久化、领域状态流转、查询、同步协调等职责；
- 为修复单一现象继续增加 fallback / compatibility branch，会让代码越来越难判断真实行为；
- 产品 V2 已明确重新设计 Phone / Pad 信息架构、科目/日期筛选、课内/课外统一 Assignment，因此继续在旧 UI 上优化的收益低于重构成本。

项目不能采用“全部推翻后一次性重写”的高风险方式，也不能采用“旧结构继续叠补丁”的方式。

## Decision

采用：

> **后端增量演进 + 前端平行替换 + 纵向切片迁移 + 切换即清理**

### 1. 保留什么

保留已经验证且方向正确的基础能力：

- ArkTS + ArkUI；
- HarmonyOS 本地持久化与离线读取能力；
- Spring Boot 模块化单体；
- PostgreSQL / JPA / Flyway；
- family / student 数据隔离；
- auth session；
- submission 文件上传与鉴权读取；
- tutor session / message；
- AI Provider 服务端适配；
- backend real E2E smoke。

这些能力通过增量演进适配 V2，而不是重写。

### 2. 替换什么

V2 前端逐步替换：

- `AppShell` 中的业务路由职责；
- Feature 页面直接访问 `HomeworkStore.instance`；
- 页面通过 sizeClass 直接决定 Phone/Pad 双栏；
- 旧 Student Today / Assignment / Study 等不符合 V2 原型的页面组合；
- 家长端旧 Dashboard / Progress / Import 页面组合。

V2 后端逐步演进：

- Assignment 早期字段模型；
- `dueText` 作为查询依据；
- 客户端任意 PATCH status/timing；
- `OVERDUE` 作为必须持久化的状态。

### 3. 不允许什么

明确禁止以下做法：

#### 3.1 UI / responsive 补丁

禁止：

- `if (isPhone)` / `if (isPreview)` / `if (deviceModel == ...)` 决定业务布局；
- Feature 页面自行新增 600 / 840 / 1080 等 magic breakpoint；
- 为某一个页面或某一种窗口尺寸添加特殊 Row/Column fallback；
- 通过不断增加默认宽度、display fallback、特殊转换来掩盖容器尺寸来源不清的问题。

允许：

- App 级导航根据窗口能力选择底部导航 / 侧边导航；
- Feature 组合通过统一 Layout Capability，基于实际容器可用宽度和每个 pane 的最小可读宽度决定单栏/多栏。

#### 3.2 测试 / CI 特判

禁止生产代码根据：

- 测试 ID；
- Mock 数据固定值；
- CI 环境变量；
- Preview 环境；
- 某个特定 E2E 场景

改变正常业务行为。

测试失败时，应修复真实实现，或修复测试中已经失效的假设。

#### 3.3 永久兼容层

兼容层只允许用于迁移期间桥接旧实现与 V2，实现时必须同时明确：

1. 它桥接的旧对象；
2. 它替换后的新对象；
3. 删除条件；
4. 最迟删除切片。

兼容逻辑必须集中在 adapter / legacy boundary，不能散落在 Page、ViewModel、领域 Service、Entity 中。

#### 3.4 两套平行业务模型

禁止长期维护：

- `Assignment` + `ExtraHomework` 两套领域；
- V1 / V2 两套 Assignment 状态机；
- V1 / V2 两套提交链路；
- V1 / V2 两套同步协议；
- PhoneModel / PadModel 两套数据模型。

课内 / 课外、Phone / Pad 都必须复用统一领域和接口契约。

### 4. 切换即清理

一个 Feature 完成 V2 切换后：

- 默认路由必须指向 V2；
- 如果旧页面不再承担 fallback 责任，应立即删除；
- 删除只服务旧页面的组件；
- 删除旧路由枚举和 selectedId / returnRoute 等状态；
- 删除旧 ViewModel / Store 方法；
- 删除过时测试；
- 删除只用于桥接已不存在调用者的 adapter。

不接受“先留着以后再删”作为默认策略。

如果因为分阶段发布必须暂时保留，PR 必须明确写出删除条件和后续切片。

### 5. main 必须持续可运行

不采用长时间不可运行的大分支重写。

每个纵向切片至少包括：

```text
Domain / DTO
  ↓
Backend API
  ↓
Repository / ViewModel
  ↓
Feature UI
  ↓
Test / E2E
  ↓
Switch
  ↓
Cleanup
```

每个切片合并后 main 都应：

- 可以编译；
- 核心门禁通过；
- 已迁移流程可运行；
- 未迁移流程仍可运行；
- 没有新增无主兼容代码。

### 6. V2 默认迁移顺序

1. Assignment V2 + Repository 基础 + Student Home；
2. Assignment List + 科目/日期/类型筛选；
3. Assignment Detail + Study Workspace + Tutor + Submission；
4. Parent Home + Progress + Parent Review；
5. Homework Import + AI 整理 + Batch Publish；
6. EXTRA Assignment + Calendar + Pad 增强；
7. 最终删除剩余 V1 页面、旧 AppShell 路由、旧 Store 业务职责和 migration adapters。

若要改变核心顺序，应先更新本 ADR / 技术设计，再修改实现。

## Clean-code acceptance criteria

V2 重构 PR 除功能验收外，还必须满足：

1. 新 V2 Feature 不直接引用 `HomeworkStore.instance`；
2. 不新增 Feature 私有设备断点；
3. 不新增 Preview / CI / 测试专用业务逻辑；
4. `AppShell` 不新增 Feature 特有状态；
5. `HomeworkStore` 公共职责数量不增加；
6. 不新建课外作业平行领域；
7. 兼容层有明确删除条件；
8. 已完成切换的旧实现同步清理；
9. 不以空 catch / silent fallback 掩盖应暴露的错误；
10. 修改优先降低总复杂度，而不是只让当前 case 通过。

## Consequences

### Positive

- 新会话 / 新 Agent 可以从仓库恢复完整设计意图；
- 避免不断为真实设备差异追加响应式补丁；
- 避免 V1/V2 长期双轨造成维护成本翻倍；
- 保留已验证后端与数据能力，降低重构风险；
- 每个阶段都有可运行产品，不依赖一次性大爆炸切换。

### Cost

- 每个纵向切片除了实现新能力，还要承担对应旧代码清理；
- 短期内 Repository 可能需要桥接旧 Store；
- 迁移期间需要同时维护“已迁移”和“尚未迁移”边界，但该边界必须持续收缩。

## Source of truth

发生冲突时，按以下优先级理解：

1. 最新 Accepted ADR；
2. `CONTEXT.md`；
3. V2 system / frontend / backend technical design；
4. V2 product feature baseline；
5. V1 历史设计文档。

任何实现如果需要违背本文原则，应先提交新的 ADR 修改决策，而不是直接在代码中增加例外。
