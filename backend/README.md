# 小伴作业 Backend V0.1

一个 Spring Boot 模块化单体：家庭/账号/孩子、已确认作业、后续提交与 Tutor 的服务端入口。第一阶段不使用 Redis、MQ、网关或微服务。

## 本地启动

前置：JDK 21、Maven 3.6.3+、Docker。

PowerShell/CMD 单行：

```powershell
docker compose -f backend/docker-compose.yml up -d
```

```powershell
cd backend; mvn spring-boot:run
```

默认本地账号：`parent / parent123`。部署环境必须通过 `BOOTSTRAP_PASSWORD` 修改密码，或将 `BOOTSTRAP_ENABLED=false`。

## 最小验证

```powershell
curl http://localhost:8080/api/v1/health
```

登录：

```powershell
curl -X POST http://localhost:8080/api/v1/auth/login -H "Content-Type: application/json" -d "{\"loginName\":\"parent\",\"password\":\"parent123\"}"
```

拿到 token 后，请求均带：`Authorization: Bearer <token>`。

## 边界

- OCR、老师消息解析、Candidate 确认继续留在 HarmonyOS 端。
- 只有确认发布后的 Assignment 进入云端。
- Bearer token 当前保存在服务进程内，服务重启后重新登录；后续真有需求再升级 JWT/持久 Session。
