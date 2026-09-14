# 小伴作业 Backend V0.1

一个 Spring Boot 模块化单体：家庭/账号/孩子、已确认作业、提交照片，以及后续 Tutor 的服务端入口。第一阶段只使用 Spring Boot + PostgreSQL；不使用 Redis、MQ、网关、工作流或微服务。

## 本地启动

前置：JDK 21、Maven 3.6.3+、Docker。

```powershell
docker compose -f backend/docker-compose.yml up -d
```

```powershell
cd backend; mvn spring-boot:run
```

默认开发账号：`parent / parent123`。部署环境必须通过 `BOOTSTRAP_PASSWORD` 修改密码，或设置 `BOOTSTRAP_ENABLED=false`。

## 最小验证

```powershell
curl http://localhost:8080/api/v1/health
```

登录：

```powershell
curl -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d "{\"loginName\":\"parent\",\"password\":\"parent123\"}"
```

拿到 token 后，其余 API 均带 `Authorization: Bearer <token>`。

## HarmonyOS 端验证

1. 启动 PostgreSQL 和 backend。
2. DevEco 运行 App，入口选择“家长”。
3. 打开“我的 → 云端连接”。
4. 服务地址填写运行 backend 的电脑局域网地址，例如 `http://192.168.1.10:8080`；不要把手机/模拟器里的 `localhost` 当作电脑。
5. 使用默认开发账号登录并同步当前孩子。
6. 在“导入”中录入真实老师作业并确认发布；只有确认发布后的 Assignment 会上传，内置演示作业不会上传。
7. 切换另一个孩子，确认两个孩子的云端作业仍然隔离。
8. 学生提交真实作业照片后，本地提交立即成功；已连接云端时照片会异步镜像到 backend。

## V0.1 同步策略

- UI 始终读取本地 `HomeworkStore`，网络不可用时保留已有本地数据。
- 第一次连接或 App 进程重启后的首次对账，服务端已有 Assignment 优先，避免旧设备覆盖其他设备的新数据。
- 同一 App 进程已观察过远端 `version` 后，本地更新只有在远端版本未变化时才允许 PATCH；否则重新拉取服务端数据。
- 当前不做离线写队列、三方合并、CRDT 或事件总线；这些只有真实使用证明有必要时再增加。

## 当前边界

- OCR、老师消息解析、Candidate 家长确认继续留在 HarmonyOS 端。
- RawImport / Candidate 不上传服务器。
- 照片通过 `FileStorage` 接口保存，V0.1 默认落 backend 本机目录 `./data/uploads`，以后可无侵入替换成对象存储。
- Bearer token 当前保存在服务进程内，backend 重启后重新登录；暂不引入 Redis 或复杂认证基础设施。
