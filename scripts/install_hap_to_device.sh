#!/usr/bin/env bash
# 把已签名的 .hap 装到鸿蒙真机上。
#
# ⚠️ 背景：HarmonyOS（尤其 NEXT）**没有给 .hap 关联安装程序**，
#    在手机上点开下载好的 .hap 不会有任何安装动作（"暂无可用打开方式"）。
#    真机安装只有三条路：① hdc install（本脚本） ② DevEco Studio 运行
#    ③ 华为 AGC 邀请测试 / 应用市场分发。
#
# 用法（仓库根目录，Git Bash）：
#   ./scripts/install_hap_to_device.sh                    # 用本地构建产物，USB 连接
#   ./scripts/install_hap_to_device.sh -d                 # 改用服务器上的最新包
#   ./scripts/install_hap_to_device.sh -w 192.168.1.23:5555   # 无线调试（同一 Wi-Fi）
#   ./scripts/install_hap_to_device.sh -u                 # 卸载再装（默认是 -r 覆盖安装）
#
# 前置条件（手机端）：
#   设置 → 关于本机 → 连点「版本号」进开发者模式
#   设置 → 系统和更新 → 开发人员选项 → 打开「USB 调试」
#   无线：同页打开「无线调试」，用上面显示的 IP:端口
#   建议顺手关掉「设置 → 系统和更新 → 纯净模式」，否则可能被拦

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

HDC="${HDC:-E:/DevTools/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe}"
PUBLIC_BASE="${PUBLIC_BASE:-http://192.144.143.141}"
LOCAL_HAP="$REPO_ROOT/entry/build/default/outputs/default/entry-default-signed.hap"
HAP_NAME="homework-assistant-0.1.0.hap"

USE_DOWNLOAD=0
WIRELESS=""
REINSTALL=""

while getopts "dw:uh" opt; do
  case "$opt" in
    d) USE_DOWNLOAD=1 ;;
    w) WIRELESS="$OPTARG" ;;
    u) REINSTALL=1 ;;
    h) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "未知参数，用 -h 查看用法" >&2; exit 2 ;;
  esac
done

[ -x "$HDC" ] || [ -f "$HDC" ] || { echo "找不到 hdc：$HDC（用 HDC=... 指定）" >&2; exit 1; }

# ---------- 1. 准备安装包 ----------
if [ "$USE_DOWNLOAD" -eq 1 ]; then
  echo "[1/3] 从服务器下载 ${HAP_NAME} …"
  TMP_DIR="$(mktemp -d)"
  HAP="$TMP_DIR/$HAP_NAME"
  CURL_OUT="$HAP"
  if command -v cygpath >/dev/null 2>&1; then CURL_OUT="$(cygpath -w "$HAP")"; fi
  curl -fsS -m 120 -o "$CURL_OUT" "${PUBLIC_BASE}/${HAP_NAME}"
  trap 'rm -rf "$TMP_DIR"' EXIT
elif [ -f "$LOCAL_HAP" ]; then
  echo "[1/3] 使用本地构建产物"
  HAP="$LOCAL_HAP"
else
  echo "[1/3] 本地没有 $LOCAL_HAP，改为从服务器下载"
  TMP_DIR="$(mktemp -d)"
  HAP="$TMP_DIR/$HAP_NAME"
  CURL_OUT="$HAP"
  if command -v cygpath >/dev/null 2>&1; then CURL_OUT="$(cygpath -w "$HAP")"; fi
  curl -fsS -m 120 -o "$CURL_OUT" "${PUBLIC_BASE}/${HAP_NAME}"
  trap 'rm -rf "$TMP_DIR"' EXIT
fi
echo "     $(ls -l "$HAP" | awk '{print $5}') 字节  $(sha256sum "$HAP" | cut -c1-16)…"

# ---------- 2. 连接设备 ----------
echo
echo "[2/3] 查找设备 …"
if [ -n "$WIRELESS" ]; then
  echo "     无线连接 $WIRELESS （需手机与电脑同一 Wi-Fi，且手机已打开「无线调试」）"
  "$HDC" tconn "$WIRELESS" || true
  sleep 1
fi

TARGETS="$("$HDC" list targets 2>/dev/null | grep -v '^\[Empty\]$' | grep -v '^$' || true)"
if [ -z "$TARGETS" ]; then
  cat >&2 <<'EOF'

❌ 没有检测到设备。请按顺序检查：

   1. 手机：设置 → 关于本机 → 连点「版本号」7 次，进入开发者模式
   2. 手机：设置 → 系统和更新 → 开发人员选项 → 打开「USB 调试」
   3. 用数据线连接电脑，手机上弹出的「允许 USB 调试」要点「允许」
   4. 没有数据线？手机打开同一页的「无线调试」，然后重跑本脚本：
        ./scripts/install_hap_to_device.sh -w <手机IP:端口>
   5. 还不行就重启 hdc 服务：hdc kill && hdc start

   实在连不上，就改用 DevEco Studio 直接 Run（同样需要开发者模式）。
EOF
  exit 1
fi
echo "     已连接：$(echo "$TARGETS" | tr '\n' ' ')"

# ---------- 3. 安装 ----------
echo
echo "[3/3] 安装 $HAP_NAME …"
if [ -n "$REINSTALL" ]; then
  echo "     （-u：先卸载 com.gyguan.homeworkassistant）"
  "$HDC" uninstall com.gyguan.homeworkassistant || true
fi
"$HDC" install -r "$HAP"

cat <<'EOF'

如果报「签名校验失败 / signature verification failed」：
   说明当前设备不在签名 profile 的白名单里。需要把该设备用数据线连一次电脑、
   在 DevEco Studio 里重新走一次自动签名，再重新打包上传。

如果报「INSTALL_FAILED_VERIFICATION_FAILURE」或安装被静默拦截：
   关掉手机上的「设置 → 系统和更新 → 纯净模式」再试。

装好后可以在手机上直接启动；后端地址已内置为 http://192.144.143.141:8080
EOF
