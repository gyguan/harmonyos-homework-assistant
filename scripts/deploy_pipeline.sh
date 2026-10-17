#!/usr/bin/env bash
# ============================================================
# 小伴作业 (harmonyos-homework-assistant) 一键部署流水线
# 运行环境：Windows Git Bash（在仓库根目录或任意位置执行）
#
# 用法:
#   bash scripts/deploy_pipeline.sh pull     # 1. 拉取 GitHub main 最新代码
#   bash scripts/deploy_pipeline.sh build    # 2. 本地构建签名 HAP
#   bash scripts/deploy_pipeline.sh backend  # 3. 部署后端到腾讯云
#   bash scripts/deploy_pipeline.sh pads     # 4. 安装 HAP 到所有已连接 Pad
#   bash scripts/deploy_pipeline.sh all      # 1→2→3→4 全流程
#   bash scripts/deploy_pipeline.sh publish  # 5. 发布指引(AGC 需人工在 DevEco 操作)
#
# 注意: push 到 GitHub 需先解决 SSH 认证（当前 fetch 走 HTTPS 可用）
# ============================================================
set -uo pipefail

REPO_DIR="D:/code/harmonyos-homework-assistant"
# Git 工具目录：PortableGit 会随版本升级改名（1.2.0 → 1.3.0 ...），这里自动探测最新版，
# 避免写死版本号后 ssh.exe/tar.exe/scp.exe 突然找不到导致部署中止。
GIT_TOOLS="$(ls -d /c/Users/guang/.workbuddy/binaries/PortableGit/versions/*/usr/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$GIT_TOOLS" ] || GIT_TOOLS="/usr/bin"
# 非交互式 Git Bash 的 PATH 可能不含 coreutils，显式补上
export PATH="$GIT_TOOLS:$PATH"
SSH_KEY="$HOME/.ssh/id_ed25519_tencent_lighthouse"
SERVER="ubuntu@192.144.143.141"
REMOTE_DIR="/home/ubuntu/homework-app"
HDC="E:\\DevTools\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe"
HDC_POSIX="/e/DevTools/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
OHPM="/e/DevTools/DevEco Studio/tools/ohpm/bin/ohpm.bat"
HVIGORW="/e/DevTools/DevEco Studio/tools/hvigor/bin/hvigorw.bat"
HAP="$REPO_DIR/entry/build/default/outputs/default/entry-default-signed.hap"

info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

ssh_server() { "$GIT_TOOLS/ssh.exe" -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=15 "$SERVER" "$1"; }

# ---------- 1. 拉取最新代码 ----------
stage_pull() {
  info "拉取 origin/main 最新代码..."
  cd "$REPO_DIR" || fail "仓库不存在: $REPO_DIR"
  git fetch https://github.com/gyguan/harmonyos-homework-assistant.git main || fail "fetch 失败（检查网络）"
  AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count HEAD..FETCH_HEAD)
  info "本地领先 $AHEAD 个提交，远程领先 $BEHIND 个提交"
  if [ "$BEHIND" = "0" ]; then info "已是最新"; return; fi
  # 有未提交的签名配置先 stash
  if ! git diff --quiet -- build-profile.json5; then
    git stash push -m "pipeline: local signing config" build-profile.json5
    STASHED=1
  fi
  git merge FETCH_HEAD --no-edit || fail "merge 冲突，请人工处理"
  if [ "${STASHED:-0}" = "1" ]; then git stash pop; info "已恢复本地签名配置 stash"; fi
  info "拉取合并完成"
}

# ---------- 2. 构建签名 HAP ----------
stage_build() {
  info "同步 ohpm 依赖..."
  (cd "$REPO_DIR" && cmd //c "$OHPM" install --all) || fail "ohpm install 失败"
  info "构建 release HAP（约 1-5 分钟）..."
  (cd "$REPO_DIR" && "$HVIGORW" assembleHap --mode module -p product=default \
     -p buildMode=release --no-daemon > build_pipeline_log.txt 2>&1) \
    || { "$GIT_TOOLS/tail.exe" -20 build_pipeline_log.txt; fail "构建失败"; }
  [ -f "$HAP" ] || fail "产物不存在: $HAP"
  "$GIT_TOOLS/ls.exe" -la "$HAP"
  info "构建成功: $HAP"
  # 构建前记得确认 AppScope/app.json5 的 versionCode 已按需递增（AGC 上传必需）
}

# ---------- 3. 部署后端到腾讯云 ----------
stage_backend() {
  info "步骤 3.1 服务器部署前备份（数据库+照片卷）..."
  ssh_server "cd $REMOTE_DIR && bash src/backend/scripts/prod_backup.sh $REMOTE_DIR/backups 7 2>&1 | tail -3" \
    || fail "服务器备份失败，中止部署"
  info "备份完成"

  info "步骤 3.2 本地打包并上传..."
  TARBALL="D:/code/homework-deploy.tar.gz"
  # --force-local 必需: 否则 GNU tar 会把 "D:/..." 里的冒号当成远程主机名，报 "Cannot connect to D:"
  # signature/ 是本地签名材料（OpenHarmony.p12 私钥、发布 profile）：
  # 只在 .gitignore 里排除还不够，tar 默认会把它一起打进部署包上传到云端。
  (cd "$REPO_DIR" && "$GIT_TOOLS/tar.exe" --force-local \
    --exclude='./.git' --exclude='node_modules' --exclude='oh_modules' \
    --exclude='./entry/build' --exclude='./backend/target' \
    --exclude='.idea' --exclude='.workbuddy' --exclude='./signature' \
    -czf "$TARBALL" .) || fail "打包失败"
  "$GIT_TOOLS/scp.exe" -i "$SSH_KEY" -o BatchMode=yes "$TARBALL" "$SERVER:$REMOTE_DIR/" || fail "上传失败"

  info "步骤 3.3 服务器解压替换 src（保留 .env）..."
  ssh_server "cd $REMOTE_DIR && rm -rf src.old && mv src src.old && mkdir src \
    && tar -xzf homework-deploy.tar.gz -C src \
    && cp src.old/backend/.env src/backend/.env && chmod 600 src/backend/.env; \
    test -f src/backend/DEPLOY.md && echo EXTRACT_OK" || fail "解压/恢复失败"
  rm -f "$TARBALL"

  info "步骤 3.4 重建容器（后台构建 + 轮询）..."
  ssh_server "cd $REMOTE_DIR/src && nohup bash -c \
    \"sudo docker compose -f backend/docker-compose.prod.yml up -d --build; echo DONE_EXIT=\\\$?\" \
    > /tmp/deploy.log 2>&1 & echo BUILD_STARTED"
  for i in $(seq 1 60); do
    sleep 10
    # [d]ocker 中括号写法必需: 否则 pgrep -f 会匹配到自身命令行，永远返回 RUNNING，白等满 60 轮
    STATE=$(ssh_server "pgrep -f '[d]ocker compose' >/dev/null && echo RUNNING || tail -3 /tmp/deploy.log")
    echo "$STATE" | "$GIT_TOOLS/grep.exe" -q "DONE_EXIT=0" && break
    echo "$STATE" | "$GIT_TOOLS/grep.exe" -q "DONE_EXIT=[^0]" && { "$GIT_TOOLS/cat.exe" /tmp/deploy.log 2>/dev/null; fail "容器重建失败"; }
    info "构建中... ($i)"
  done

  info "步骤 3.5 等待健康检查（含 Flyway 迁移）..."
  CODE=""
  for i in $(seq 1 24); do
    CODE=$(ssh_server "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/v1/health")
    [ "$CODE" = "200" ] && break
    sleep 5
  done
  [ "$CODE" = "200" ] || fail "健康检查未通过 (code=$CODE)，检查: sudo docker logs homework-backend-app-1"
  info "健康检查通过"

  info "步骤 3.6 重建 caddy（bind mount 指向新 src 的 inode）+ 清理..."
  ssh_server "cd $REMOTE_DIR/src && sudo docker compose -f backend/docker-compose.prod.yml up -d --no-deps --force-recreate caddy \
    && rm -rf $REMOTE_DIR/src.old /tmp/deploy.log \
    && sudo docker ps --format 'table {{.Names}}\t{{.Status}}'" || fail "caddy 重建失败"
  info "后端部署完成: http://192.144.143.141:8080/api/v1/health"
}

# ---------- 4. 安装到已连接的 Pad ----------
stage_pads() {
  info "查询已连接设备..."
  TARGETS=$(powershell.exe -NoProfile -Command "& '$HDC' list targets" | tr -d '\r' | "$GIT_TOOLS/grep.exe" -E '^[0-9A-Z]+$')
  [ -n "$TARGETS" ] || fail "未检测到已连接设备（检查 USB 连接与开发者模式）"
  HAP_WIN="D:\\code\\harmonyos-homework-assistant\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap"
  for T in $TARGETS; do
    info "安装到 $T ..."
    powershell.exe -NoProfile -Command "& '$HDC' -t $T install -r '$HAP_WIN'" | tr -d '\r'
    powershell.exe -NoProfile -Command "& '$HDC' -t $T shell 'aa start -a EntryAbility -b com.gyguan.homeworkassistant'" | tr -d '\r'
  done
  info "全部设备安装并启动完成"
  # 新设备报 9568423 时: DevEco > 项目结构 > Signing Configs > 重新自动生成签名(需登录) 后重试
}

# ---------- 5. 发布指引（人工步骤） ----------
stage_publish() {
  cat <<'EOF'
AGC 发布为人工步骤（需开发者账号登录），流程如下：

1. [代码] 确认 AppScope/app.json5 的 versionCode 已在上次基础上 +1（AGC 强制）
2. [代码] 确认 entry/src/main/module.json5 无受限权限（FLOAT_VIEW 等会被 AGC 拒收）
3. DevEco > 构建 > 编译 APP(s)  → 生成 .app
4. DevEco > 构建 > 上传产品 → 登录 → AppGallery Connect → Upload（云自动签名）
5. AGC 软件包管理：等「已就绪」，删除失败旧包
6. AGC 我的应用 > 小伴作业 > 应用测试 > 版本列表 > 创建测试版本（邀请测试）
   - 测试账号 parent/parent123；隐私声明用 AGC 托管服务生成
   - 外部测试群组 > 管理 > 添加测试用户 > 获取公开链接发给家人
详见 store-assets/AGC_INVITE_TEST_GUIDE.md（逐屏手册）
EOF
}

case "${1:-help}" in
  pull)    stage_pull ;;
  build)   stage_build ;;
  backend) stage_backend ;;
  pads)    stage_pads ;;
  publish) stage_publish ;;
  all)     stage_pull; stage_build; stage_backend; stage_pads ;;
  *) stage_publish ;;
esac
