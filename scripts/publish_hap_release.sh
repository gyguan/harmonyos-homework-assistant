#!/usr/bin/env bash
# 一键发布 HarmonyOS 客户端安装包到云端下载站。
#
#   1. hvigorw 打 release 包          -> entry-default-signed.hap
#   2. hap-sign-tool 校验签名          -> 不通过就中止
#   3. scp 上传到 <部署根>/releases/    -> homework-assistant-<版本>.hap
#   4. 从公网地址回抓一次，比对 SHA-256 -> 不一致就报错
#
# 服务器与目录约定见 backend/DEPLOY.md 第十节。
#
# 用法（在仓库根目录，Git Bash）：
#   ./scripts/publish_hap_release.sh              # 完整流程
#   ./scripts/publish_hap_release.sh -s           # 跳过构建，只上传现有包
#   ./scripts/publish_hap_release.sh -v 0.2.0     # 指定版本号
#
# Windows 用户请在 Git Bash 中运行；纯 PowerShell 环境请按 DEPLOY.md 10.4 手工执行。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEVECO_HOME="${DEVECO_HOME:-E:/DevTools/DevEco Studio}"
SERVER="${SERVER:-ubuntu@192.144.143.141}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_tencent_lighthouse}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/home/ubuntu/homework-app/src}"
PUBLIC_BASE="${PUBLIC_BASE:-http://192.144.143.141}"

SKIP_BUILD=0
VERSION=""

while getopts "sv:h" opt; do
  case "$opt" in
    s) SKIP_BUILD=1 ;;
    v) VERSION="$OPTARG" ;;
    h) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数，用 -h 查看用法" >&2; exit 2 ;;
  esac
done

SSH_OPTS=(-o "IdentityFile=$SSH_KEY" -o "StrictHostKeyChecking=accept-new" -o "ConnectTimeout=15")
SIGNED_HAP="$REPO_ROOT/entry/build/default/outputs/default/entry-default-signed.hap"

# ---------- 0. 版本号 ----------
if [ -z "$VERSION" ]; then
  VERSION="$(grep -o '"versionName"[[:space:]]*:[[:space:]]*"[^"]*"' AppScope/app.json5 \
             | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
fi
[ -n "$VERSION" ] || { echo "无法解析 versionName，请用 -v 指定" >&2; exit 1; }
HAP_NAME="homework-assistant-${VERSION}.hap"
echo "发布版本：$VERSION  ->  $HAP_NAME"

# ---------- 1. 构建 ----------
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo
  echo "[1/5] 构建 release 包 …"
  DEVECO_SDK_HOME="$DEVECO_HOME/sdk" \
    "$DEVECO_HOME/tools/node/node.exe" "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" \
    assembleHap --mode module -p product=default -p buildMode=release --no-daemon
else
  echo
  echo "[1/5] 跳过构建（-s）"
fi

[ -f "$SIGNED_HAP" ] || { echo "找不到签名包：$SIGNED_HAP" >&2; exit 1; }

# ---------- 2. 校验签名 ----------
echo
echo "[2/5] 校验 HAP 签名 …"
VERIFY_LOG="$("$DEVECO_HOME/jbr/bin/java.exe" -jar \
  "$DEVECO_HOME/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar" \
  verify-app -inFile "$(cygpath -w "$SIGNED_HAP")" \
  -outCertChain "$(cygpath -w "$REPO_ROOT/.verify_chain.cer")" \
  -outProfile "$(cygpath -w "$REPO_ROOT/.verify_profile.p7b")" 2>&1 || true)"
echo "$VERIFY_LOG" | grep -E 'Digest verify|verify-app' || true
echo "$VERIFY_LOG" | grep -q 'verify-app success' || { echo "签名校验未通过" >&2; exit 1; }
rm -f "$REPO_ROOT/.verify_chain.cer" "$REPO_ROOT/.verify_profile.p7b"

# ---------- 3. 哈希 ----------
echo
echo "[3/5] 计算 SHA-256 …"
LOCAL_SHA="$(sha256sum "$SIGNED_HAP" | awk '{print $1}')"
SIZE_KB=$(( $(stat -c%s "$SIGNED_HAP") / 1024 ))
echo "    $LOCAL_SHA  (${SIZE_KB} KB)"

# ---------- 4. 上传 ----------
echo
echo "[4/5] 上传到 ${SERVER}:${DEPLOY_ROOT}/releases/ …"
ssh "${SSH_OPTS[@]}" "$SERVER" "mkdir -p '$DEPLOY_ROOT/releases'"
scp "${SSH_OPTS[@]}" "$SIGNED_HAP" "${SERVER}:${DEPLOY_ROOT}/releases/${HAP_NAME}"

# ---------- 5. 回抓校验 ----------
echo
echo "[5/5] 从公网回抓校验 …"
TMP_DIR="$(mktemp -d)"
TMP="$TMP_DIR/verify-download.hap"
# Git Bash 下 mktemp 返回 /tmp/xxx，Windows 原生 curl 写不了这个路径，需转成盘符路径
CURL_OUT="$TMP"
if command -v cygpath >/dev/null 2>&1; then CURL_OUT="$(cygpath -w "$TMP")"; fi
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsS -m 120 -o "$CURL_OUT" "${PUBLIC_BASE}/${HAP_NAME}"
REMOTE_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
[ "$REMOTE_SHA" = "$LOCAL_SHA" ] || { echo "哈希不一致！本地 $LOCAL_SHA / 线上 $REMOTE_SHA" >&2; exit 1; }

cat <<EOF

============================================
 发布完成
============================================
 下载页  : ${PUBLIC_BASE}/
 安装包  : ${PUBLIC_BASE}/${HAP_NAME}
 大小    : ${SIZE_KB} KB
 SHA-256 : ${LOCAL_SHA}

 提示：版本号变了的话，记得同步更新 releases/index.html 里的下载链接和哈希。
EOF
