# 服务端云端部署指南

小伴作业后端 = 一个 Spring Boot 4.1 单体 + 一个 PostgreSQL 17，无 Redis / MQ / 网关。
部署形态：Docker Compose 两个容器（`db` + `app`），数据落在两个 named volume 里。

## 一、前置要求

- 一台 Linux 服务器（推荐 2 核 4G 以上，Ubuntu 22.04 / Debian 12 / OpenCloudOS 均可）
- 已安装 Docker Engine 与 Docker Compose 插件
- 能通过 SSH 访问服务器，并能 git clone（或把仓库打包上传）

### 服务器选购参考（腾讯云轻量应用服务器，2026-09 活动价，随时变动）

| 配置 | 硬盘 / 流量 / 带宽 | 活动价 | 适合 |
|---|---|---|---|
| 2核2G | 40GB SSD / 200GB月 / 3M | ~68 元/年 | 最低可用：需加 2G swap 再构建镜像 |
| **4核4G（秒杀款）** | 40GB SSD / 300GB月 / 3M | ~38 元/年（每日 10:00/15:00 秒杀） | **性价比最优，优先抢这个** |
| 2核4G | 70GB SSD / 600GB月 / 6M | ~528 元/3年 | 照片加载体验更好（6M 带宽） |

要点：
- 数据库**不要**单独买云数据库 PostgreSQL（TencentDB 贵一个数量级），本方案 PG 就跑在同一台的 Docker 里
- 新人价仅限新用户账号；注意看「续费同价」标识，避免首年便宜续费翻倍
- 地域选离你最近的（广州/上海/北京），镜像选 Ubuntu 22.04/24.04 纯系统镜像
- 2核2G 机型构建镜像前先加 swap：`fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile`（并写入 /etc/fstab）


## 二、部署步骤

```bash
# 1. 拉代码
git clone https://github.com/gyguan/harmonyos-homework-assistant.git
cd harmonyos-homework-assistant/backend

# 2. 配置环境变量（复制模板后编辑，改掉两个"请改成强密码"）
cp .env.example .env
vi .env

# 3. 构建并启动（首次构建要下载 Maven 依赖，约 5~15 分钟）
docker compose -f docker-compose.prod.yml up -d --build

# 4. 验证
curl http://localhost:8080/api/v1/health
docker compose -f docker-compose.prod.yml ps   # 两个容器都应为 healthy
```

首次启动时 Flyway 会自动执行 V1~V8 迁移建表，并按 `.env` 创建初始家长账号。

## 三、网络与安全（重要）

0. **腾讯云轻量应用服务器默认只放行 22 端口**：部署后必须在控制台放行应用端口，否则外网访问不通。
   控制台 → 轻量应用服务器 → 目标实例 → **防火墙** → 添加规则 → 应用类型「自定义」→ 协议 **TCP** → 端口 **8080**（或 80/443）→ 来源「全部 IPv4」。注意：在服务器上改主机级 iptables 无效——拦截发生在云端网络层。
1. **云安全组只放行需要的端口**：80 / 443（对外），SSH 端口限来源 IP。**不要**把 5432 暴露到公网（生产 compose 默认就没映射数据库端口）。
2. **HTTPS 用 Caddy 自动签发证书**（compose 里已内置 `caddy` 服务，配好 `Caddyfile` 即可）：

   ```
   # 无需自己写 Caddyfile，仓库 backend/Caddyfile 已就绪
   # 只需在 .env 里指定域名（不配则默认 192-144-143-141.sslip.io）
   SITE_ADDRESS=homework.example.com
   ```

   端口放行：**443 必须开**（走 TLS-ALPN 验证），80 建议开（HTTP 跳转 + HTTP-01 备用）。

   ⚠️ **中国大陆服务器的备案拦截坑（实测）**：
   - 未备案域名走 **80 端口**会被腾讯云网络层拦截，Let's Encrypt 的 `http-01` 挑战会拿到
     `dnspod.qcloud.com/static/webblock.html` 拦截页（HTTP 566）→ 签约失败。
   - 实测该拦截发生在**云网络层**（比实例防火墙更靠前），主机上无法规避。
   - **解法（有望成功）**：走 **443 端口的 `tls-alpn-01` 挑战**可绕开 80 端口拦截（前提 443 已放行且 SNI 未被 reset）。
     Caddy 会自动先试 http-01 再试 tls-alpn-01，无需额外配置。
   - **实测更深一层的坑**：即使 443 TCP 已放行，对未备案域名发起 TLS 握手（ClientHello 带 SNI = 该域名）时，
     连接仍会被中间设备 **RST** 重置。表现为 `tls-alpn-01` 已响应认证证书，但 Let's Encrypt 报告
     `Connection reset by peer`。因此 443 放行后，**大陆节点 + 未备案域名 + HTTPS 仍走不通**。
   - 最终选择：① 域名完成 ICP 备案后再启用 HTTPS；② 换中国香港/海外节点；③ **退回 HTTP（`http://IP:8080`，当前实际使用方案）**。App 已通过 `network_config.json` 放行明文 HTTP。
3. `.env` 里的 `BOOTSTRAP_PASSWORD` 是家长账号**首次启动时创建**用的初始密码，**必须改掉默认值**。

   > 本实例的家长登录名为 `parent`，密码请到服务器上查看：
   > `grep '^BOOTSTRAP_PASSWORD=' backend/.env`（**密码不写进仓库**）。

   ⚠️ **改密码不要只改 `.env`！**`LocalBootstrap` 的逻辑是：账号已存在就直接 `return`，**不会**用 `.env` 里的新密码覆盖数据库**。因此一旦账号创建成功后再改密码，需要直接更新数据库：

   ```bash
   # 在服务器上执行：把 parent 账号密码改成你想要的新密码
   PSQL="docker exec homework-backend-db-1 psql -U $(grep '^DB_USERNAME=' .env | cut -d= -f2-) -d homework"
   $PSQL -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
   $PSQL -c "UPDATE account SET password_hash = crypt('新密码', gen_salt('bf', 10)), updated_at = now() WHERE login_name='parent';"
   ```

   密码采用 BCrypt 编码（Spring Security `BCryptPasswordEncoder`），所以用 PostgreSQL 的 `pgcrypto` 生成同格式哈希。改完 `.env` 的 `BOOTSTRAP_PASSWORD` 也要同步改，防止将来重建数据库时再次 mismatch。
4. 生产 compose 已默认 `HTTP_LOG_PAYLOADS=false`，业务报文不会写日志。

## 四、App 端连接

App 不需要重新编译：家长端 → 设置 → **后端连接**页，填入后端地址和账号密码即可。

- 当前云端地址：**`http://192.144.143.141:8080`**（已放行，可用）
- 当前家长账号：**`parent`**（密码见服务器 `backend/.env`，不在仓库里）
- 若将来域名完成 ICP 备案/换海外节点，可改用 `https://你的域名`；届时只需在 App 内设置页切换，无需重编
  `AppConfig.BACKEND_BASE_URL` 里的局域网地址只是开发默认值，运行时会被设置页覆盖。

连接失败时先看服务器日志：

```bash
# 在服务器上执行
sudo docker logs --since 5m homework-backend-app-1 2>&1 | grep 'auth.login'
```

- `-> 200` = 账号密码正确，问题在 App 端（地址/明文 HTTP 配置）
- `-> 401` = 账号或密码错误；对照 `grep '^BOOTSTRAP_PASSWORD=' .env` 确认密码，并按第三节的方法改数据库

## 五、日常运维

```bash
# 更新版本
cd harmonyos-homework-assistant && git pull
docker compose -f backend/docker-compose.prod.yml up -d --build

# 看日志
docker compose -f backend/docker-compose.prod.yml logs -f app

# 重启
docker compose -f backend/docker-compose.prod.yml restart
```

### 备份（已提供脚本，建议加入 cron 每天执行一次）

```bash
# 备份数据库 + 作业照片卷（默认保留 7 天，输出到 /home/ubuntu/homework-app/backups）
backend/scripts/prod_backup.sh [备份目录] [保留天数]

# 安装每日 3:30 定时任务
( crontab -l 2>/dev/null | grep -v prod_backup.sh; \
  echo "30 3 * * * /home/ubuntu/homework-app/src/backend/scripts/prod_backup.sh >> /home/ubuntu/homework-app/backups/backup.log 2>&1" ) | crontab -
```

脚本产出的两类文件（示例：`db-2026-09-19_180024.sql.gz`、`uploads-2026-09-19_180024.tar.gz`），恢复方法见脚本头部注释。

> 脚本实现要点（踩过坑）：应用镜像 `ENTRYPOINT` 是 `java -jar`，用容器备份卷时必须 `--entrypoint tar` 覆盖，
> 且该镜像**没有 gzip**，因此 tar 输出到 stdout、由宿主机 gzip 压缩。
>
> 卷名默认为 `homework-backend_pgdata` / `homework-backend_uploads`（compose 项目名 `homework-backend` + 卷名），可用 `docker volume ls` 确认。

## 六、常见问题

| 现象 | 处理 |
|---|---|
| `app` 容器反复重启 | `logs app` 看原因；多数是 `.env` 没填或密码含特殊字符没加引号 |
| 健康检查一直不健康 | 首次启动 Flyway 迁移 + JVM 预热需要时间，`start-period` 已放宽到 90s，再等一会 |
| 想换端口 | `.env` 里设 `APP_PORT=18080`，然后 `up -d` |
| AI Tutor 不可用 | 属预期降级；在 `.env` 配 `AI_API_KEY` 等变量后 `up -d` 即可启用 |
| App 提示「连接失败，请检查...」 | 绝大多数情况是**密码错**；服务端 `auth.login` 日志 `-> 401` 即确认。改密码参考第三节 |
| 服务器内存不足 | App 容器已设 `-XX:MaxRAMPercentage=75`，1G 小机型也能跑，但建议 ≥2G |

## 七、部署实况记录（2026-09-19，腾讯云轻量应用服务器）

| 项 | 值 |
|---|---|
| 公网 IP | `192.144.143.141` |
| 系统 | Ubuntu 24.04.4 LTS，2 核 / 1.9 GB 内存 / 40 GB 磁盘（自带 1.9G swap） |
| 登录用户 | `ubuntu`（sudo 免密），SSH 密钥部署，免密登录 |
| 代码位置 | `/home/ubuntu/homework-app/src`（由本地打包上传，非 git clone） |
| 后端目录 | `/home/ubuntu/homework-app/src/backend`（`.env` 在此，权限 600） |
| 容器 | `homework-backend-app-1`、`homework-backend-db-1`（healthy）、`homework-backend-caddy-1`（HTTPS 反代），重启策略均 `unless-stopped` |
| 对外地址 | `http://192.144.143.141:8080`（已放行，可用）；443 端口已放行但 HTTPS（`https://192-144-143-141.sslip.io`）仍被中间设备按 SNI 重置，未备案域名在大陆节点暂不可用，当前退回到 HTTP |
| 备份 | `backend/scripts/prod_backup.sh` 已部署到服务器，crontab 每日 **03:30** 执行，保留 7 天，日志 `backups/backup.log` |
| 账号 | 家长登录名 `parent`，密码见服务器 `backend/.env`（不写进仓库）。改密码需直接 UPDATE `account` 表，原因见第三节 |

服务器侧构建加速配置（国内网络必需）：
- Docker 镜像加速 `/etc/docker/daemon.json`：`mirror.ccs.tencentyun.com`、`docker.1ms.run`
- 镜像内 Maven 走阿里云：Dockerfile 构建层写入 `/root/.m2/settings.xml`
- 镜像内 apt 走 `mirrors.cloud.tencent.com`（Dockerfile 运行层已 sed 替换）

无密钥操作服务器的示例（本机已存专用密钥 `~/.ssh/id_ed25519_tencent_lighthouse`）：

```bash
ssh -i ~/.ssh/id_ed25519_tencent_lighthouse ubuntu@192.144.143.141
```

> 说明：服务器上 Docker 命令需 `sudo`（`ubuntu` 已加入 docker 组，重新登录后可直接用）。

## 八、App 端打包与真机安装（2026-09-19 实测）

### 8.1 客户端已做的改动

| 文件 | 改动 | 原因 |
|---|---|---|
| `entry/src/main/ets/common/config/AppConfig.ets` | `BACKEND_BASE_URL` = `http://192.144.143.141:8080` | 默认指向云端（App 内「设置 → 后端连接」仍可改） |
| `entry/src/main/resources/base/profile/network_config.json` | `cleartextTrafficPermitted: true` | HarmonyOS NEXT 默认**禁止明文 HTTP**，不放行 App 连不上 HTTP 后端。按文件名约定自动生效，无需在 `module.json5` 里引用 |
| `scripts/sign_hap_release.ps1` | 自签名脚本 | 仅用于 OpenHarmony 设备 / 模拟器 |

### 8.2 命令行构建

```bash
# 在仓库根目录执行（hvigorw 由 DevEco 自带，需先把工具链加进 PATH）
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=release --no-daemon
# 产物：entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 8.3 签名：自签名包**装不进华为商用设备**（重要）

实测结论（HUAWEI MatePad 11.5''S，TGR-W00，HarmonyOS 6.1.0.135）：

| 步骤 | 结果 |
|---|---|
| `hap-sign-tool` 自签名 + `verify-app` | ✅ verify success（codesign / digest / permission 全过） |
| `hdc install` 自签名包到真机 | ❌ `code:9568257 error: fail to verify pkcs7 file` |

原因：商用 HarmonyOS 设备只信任 **华为 AGC 签发的证书与 profile**，自签名链不在信任根内。
自签名包**只能**装到 OpenHarmony 设备或 DevEco 模拟器。

**真机安装的唯一正路 = DevEco 登录华为账号做「自动签名」**（命令行无法替代）：

1. USB 连上设备，设备端打开「开发者选项 → USB 调试」并同意调试授权（`hdc list targets` 能看到序列号即 OK）
2. DevEco：`File → Project Structure → Signing Configs` → 勾选 **Automatically generate signature** → 登录华为账号
3. 若报 **「缺少设备导致无法新建profile文件」**：说明 IDE 没枚举到设备。确认 `hdc list targets` 有设备、IDE 底部 Devices 面板能看到它，再点一次自动签名
4. 成功后 IDE 会回写 `build-profile.json5` 的 `signingConfigs`，签名材料落在 `%USERPROFILE%\.ohos\config\openharmony\`
5. 之后 `Build → Build Hap(s)` 出的包即可 `hdc install` 到真机

排错用日志：`%LOCALAPPDATA%\Huawei\DevEcoStudio26.0\log\idea.log`，搜关键词
`AutoSigningConfigsService` / `checkDeviceInfo` / `developerSignAgr`。

### 8.4 hdc 使用注意

- `hdc install <路径>` 会把参数当**相对路径**拼当前工作目录，传 `C:/...` 这种正斜杠绝对路径会报
  `Error opening file: no such file or directory`。**先 `cd` 到 hap 所在目录，只传文件名。**
- 常用：`hdc list targets`、`hdc -t <序列号> shell bm get -u`（取 UDID）、`hdc -t <序列号> install x.hap`
- 模拟器安装**不需要签名**（IDE 会提示「如果是在模拟器上安装HAP包，可以跳过签名这一步骤」）

### 8.5 模拟器前置（已解决）

鸿蒙模拟器要求 Windows 开启 Hyper-V，**两层都要满足**：

1. **BIOS**：Lenovo 开机 F1 → `Security → Virtualization → Intel(R) Virtualization Technology = Enabled` → F10 保存
2. **Windows**：启用 `Microsoft-Hyper-V-All` / `HypervisorPlatform` / `VirtualMachinePlatform` 三个组件后重启

判断是否真的生效：`(Get-CimInstance Win32_ComputerSystem).HypervisorPresent` 为 **True** 即成功。
注意此时 `Win32_Processor.VirtualizationFirmwareEnabled` 反而会显示 False（被 hypervisor 接管后的正常现象），**不要**据此判断失败。

---

## 九、AI 大模型接入（2026-09-19 实测）

服务端 `app.ai.*` 走标准 **OpenAI 兼容协议**，换厂商只改环境变量，**不用改一行 Java**。两个使用点：AI 答疑（`tutor`，自由问答 700 tokens）与作业整理（`organizer`，结构化输出 1400 tokens）。

### 9.1 配置（写进 `.env` 后 `docker compose up -d`）

```bash
AI_PROTOCOL=chat-completions
AI_API_KEY=<你的Key>
AI_BASE_URL=https://open.bigmodel.cn/api/paas/v4
AI_CHAT_COMPLETIONS_PATH=/chat/completions
AI_TUTOR_MODEL=glm-4-flash
AI_ORGANIZER_MODEL=glm-4-flash
AI_STRUCTURED_OUTPUT=false
```

`docker-compose.prod.yml` 必须把 `AI_*` 全部透传进容器，否则容器内拿到的仍是默认值（`baseUrl=https://api.openai.com`、Key 为空），AI 静默不生效。
**启动日志里那行 `[AI] config ...` 是唯一可靠的判据**，能看到 `protocol=` / `keyConfigured=` 才算配好。

### 9.2 ⚠️ 最大的坑：`responses` 协议只有 OpenAI 支持

`AI_PROTOCOL` 默认值是 `responses`，即 OpenAI 的 **Responses API**（路径 `/v1/responses`），**国内厂商无一支持**。
照默认值配国内地址，请求会打到 `.../api/paas/v4/v1/responses` → **404 → 静默降级到无 AI**，日志里只留一行 `[AI] response error ... status=404`，很容易误判成"Key 不对"。

接任何国内厂商，**第一件事就是把 `AI_PROTOCOL` 改成 `chat-completions`**。

### 9.3 各厂商端点（逐个实测，路径正确时返回 401）

| 厂商 | `AI_BASE_URL` | `AI_CHAT_COMPLETIONS_PATH` | 免费额度 |
|---|---|---|---|
| 智谱 BigModel | `https://open.bigmodel.cn/api/paas/v4` | `/chat/completions` | `glm-4.7-flash` / `glm-4-flash` 永久免费 |
| 硅基流动 | `https://api.siliconflow.cn` | 默认 `/v1/chat/completions` | 注册赠 2000 万 token，9B 以下永久免费 |
| 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode` | 默认 | 每模型 100 万 token / 90 天 |
| 火山方舟 | `https://ark.cn-beijing.volces.com/api/v3` | `/chat/completions` | 每日 200 万 token，每日重置 |
| 百度千帆 | `https://qianfan.baidubce.com/v2` | `/chat/completions` | `ernie-speed-128k` 永久免费 |
| 腾讯混元 | `https://api.hunyuan.cloud.tencent.com` | 默认 | 开通赠 100 万 token / 1 年 |

注意**有些厂商把版本号放在 BASE_URL 里**（智谱 `/v4`、火山 `/api/v3`、千帆 `/v2`），路径要相应改成短的 `/chat/completions`，否则会 404。

**境外免费档直接排除**：从大陆节点实测 `api.openai.com`、`generativelanguage.googleapis.com` 均 8 秒超时（`http=000`），Gemini / Groq / OpenRouter 的免费额度在这台机器上用不了。

### 9.4 ⚠️ `response_format: json_schema` 会被静默忽略

`organizer` 靠 `json_schema` + `strict:true` 强约束输出。实测智谱免费模型返回 **HTTP 200 但完全无视 schema**：要求 8 个字段，只回 `subject` + `description`，字段名对不上 → Jackson 解析后 `title` 为空 → 被 `toCandidates` 全部拒收 → 日志 `organizer rejected all model assignments`，功能静默失效。

**结论：接国内模型一律设 `AI_STRUCTURED_OUTPUT=false`**，退回"提示词要求 JSON + 代码解析"。
后端 `ConfigurableHomeworkOrganizerModelClient.stripCodeFence()` 已能剥掉 ` ```json ` 围栏，且对缺失的 `textbookRef` / `dueText` 有默认值兜底（`待家长确认` / `今天`）。

> 关掉 schema 约束后输出依然完整，前提是**提示词不能省**——它已经逐字段写明了 `subject/title/instruction/textbookRef/dueText/expectedMinutes/sourceExcerpt/confidence`。

### 9.5 模型容量：`glm-4.7-flash` 当时不可用

同一账号、相隔数分钟连续实测：

| 模型 | 基础对话 | 带 json_schema | 结论 |
|---|---|---|---|
| `glm-4.7-flash` | **429 / `1305` 访问量过大** | 429 | 免费档容量紧张，**当时不可用** |
| `glm-4.5-flash` | 200，12.2 s | >90 s 超时 | 能通但太慢 |
| `glm-4-flash` | **200，1.8 s** | 200（schema 被忽略） | **稳定可用 → 选它** |

所以线上配的是 `glm-4-flash` 而非更新的 `glm-4.7-flash`。若 4.7 后续恢复，改 `AI_TUTOR_MODEL` / `AI_ORGANIZER_MODEL` 即可切换。

### 9.6 端到端验证结果（`mode = AI`，非降级）

用家长账号真实调用后端接口：

- **作业整理** `POST /api/v1/students/{studentId}/homework/organize` → 200，14.6 s，`mode=AI`
  输入一段混有"带校服费""开家长会"的老师通知，正确拆出 **3 条**作业（语文 30 min / 数学 20 min / 英语 15 min），**非作业内容全部忽略**；日志 `accepted=3 unsupportedSubject=0 blankTitle=0`。
- **AI 答疑** `POST /api/v1/assignments/{id}/tutor/messages` → 200，2.7 s，`available=true`
  问「48乘7怎么算」，返回**引导式**回答（提示拆成 8×7 与 40×7，反问"你先算出 8 乘以 7 是多少"），符合 `guidanceFirst=true / directAnswerAllowed=false` 的语义。

### 9.7 成本

`glm-4-flash` 单价 0 元，但**免费档有并发与速率限制**（智谱免费模型并发很低），适合家庭单用户场景，**不要用于多用户并发**。

