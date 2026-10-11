# 部署流水线总览（deploy_pipeline）

> 一键脚本：`bash scripts/deploy_pipeline.sh <stage>`，支持 `pull / build / backend / pads / publish / all`
> 运行环境：Windows Git Bash。各阶段也可独立执行。

## 流程总图

```
① pull  拉取最新代码 ──► ② build 构建 HAP ──► ③ backend 部署后端(腾讯云) ──► ④ pads 真机安装 ──► ⑤ publish AGC 发布(人工)
```

## ① 拉取最新代码

- 远程：`https://github.com/gyguan/harmonyos-homework-assistant` main 分支（fetch 走 HTTPS，push 目前需先配 SSH 密钥）
- 脚本自动处理：`build-profile.json5` 本地签名改动先 stash，merge 后恢复
- 冲突时脚本中止，需人工 `git merge` 处理

## ② 构建签名 HAP

1. `ohpm install --all` 同步依赖（合并新模块后必须）
2. `hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon`
   - hvigorw 用 DevEco 自带：`E:\DevTools\DevEco Studio\tools\hvigor\bin\hvigorw.bat`（仓库根目录没有 hvigorw.bat）
3. 产物：`entry/build/default/outputs/default/entry-default-signed.hap`
4. ⚠️ 若要上传 AGC：先递增 `AppScope/app.json5` 的 `versionCode`，并确认 `module.json5` 无受限权限（如 `FLOAT_VIEW`，会被 AGC 判「合法性校验不通过」）

## ③ 部署后端到腾讯云

- 服务器：腾讯云轻量 `192.144.143.141`（Ubuntu 24.04），SSH 密钥 `~/.ssh/id_ed25519_tencent_lighthouse`
- 形态：Docker Compose 三容器 app + PostgreSQL 17 + caddy，目录 `/home/ubuntu/homework-app`
- 脚本步骤：
  1. 部署前备份（`backend/scripts/prod_backup.sh`，每日 03:30 也有 crontab 自动备份）
  2. tar 打包（排除 .git/build/node_modules 等）→ scp 上传 → 替换 `src`
  3. 恢复不入库文件：`src/backend/.env`（含数据库密码）和 `src/releases/*.hap`（下载站安装包）
  4. `docker compose -f backend/docker-compose.prod.yml up -d --build`（Flyway 迁移自动执行）
  5. 轮询 `http://localhost:8080/api/v1/health` 到 200
  6. `--force-recreate caddy`（⭐替换 src 目录后 bind mount 还挂旧 inode，必须重建）
  7. 清理 `src.old` 和临时 tar
- 详细运维（改密码、排错、回滚）：`backend/DEPLOY.md`

## ④ 安装到本地 Pad 测试

- hdc：`E:\DevTools\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`
- 脚本自动对所有已连接设备 `install -r` 并启动应用（bundle: `com.gyguan.homeworkassistant`）
- 坑：hdc 是原生 Windows 程序，参数必须用 Windows 盘符路径（脚本内已通过 PowerShell 包装处理）
- **新设备报错 9568423**（UDID 不在调试签名档案）：DevEco → 项目结构 → Signing Configs → 取消再勾选「自动生成签名」（需登录华为账号）→ 重新构建 → 重装。白名单上限 100 台。

## ⑤ AGC 发布（人工）

- DevEco「构建 > 编译 APP(s)」→「构建 > 上传产品」（云端自动重签名）→ AGC 创建邀请测试
- 测试账号 `parent/parent123`（已核实与云端 `.env` 的 BOOTSTRAP_PASSWORD 一致）
- 逐屏手册：`store-assets/AGC_INVITE_TEST_GUIDE.md`、`store-assets/AGC_TEST_VERSION_STEP_GUIDE.md`
- 高频卡点：账号需开发者实名（认证后 IDE 要 Sign out 重登）；公开链接在「外部测试群组 > 管理」页

## 已知约束 / 待办

- 本地 main 领先 origin/main 400+ 提交未 push（SSH 认证未配置）——push 前不要在多台机器同时改
- 后端为 HTTP 明文（域名未备案，HTTPS SSI 被重置），AGC 审核可用
- `build-profile.json5` 含本机证书路径，勿提交入库
