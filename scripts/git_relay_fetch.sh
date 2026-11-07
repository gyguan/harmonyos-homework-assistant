#!/usr/bin/env bash
# 经云服务器中转从 GitHub 拉取（fetch）最新代码。
#
# 为什么需要它：本机出网被代理限制 —— api.github.com 放行，但到 git 主机
# github.com 的 CONNECT 会被代理拒绝（502），直连则超时，因此 `git fetch`
# 走不通（schannel 报 handshake failed，openssl 后端报 CONNECT 502）。
# 云服务器 192.144.143.141 能直连 github.com，所以在服务器侧 clone 后
# 只打包「本地没有的那一段」提交，回传本地 fetch。
#
# 用法（在 Git Bash 里跑）：
#   bash scripts/git_relay_fetch.sh          # 拉取 origin/main
#   bash scripts/git_relay_fetch.sh main     # 指定分支
#
# 原理：bundle 以「本地已有 tip」为前置提交（--not <tip>），只传增量，
#       回传后 git fetch 会把对象并入本地库，并把 refs/remotes/origin/<branch>
#       指向远端真实 tip。

set -euo pipefail

REPO_DIR="D:/code/harmonyos-homework-assistant"
SERVER="ubuntu@192.144.143.141"
SSH_KEY="$HOME/.ssh/id_ed25519_tencent_lighthouse"
REMOTE_DIR="/tmp/git-relay-fetch-$$"
GIT_TOOLS="$(ls -d /c/Users/guang/.workbuddy/binaries/PortableGit/versions/*/usr/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$GIT_TOOLS" ] || GIT_TOOLS="/usr/bin"

BRANCH="${1:-main}"
REMOTE_URL="$(cd "$REPO_DIR" && git remote get-url origin)"
SSH="$GIT_TOOLS/ssh.exe -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=20"
SCP="$GIT_TOOLS/scp.exe -i $SSH_KEY -o BatchMode=yes"

info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

cd "$REPO_DIR" || fail "仓库不存在: $REPO_DIR"

LOCAL_TIP="$(git rev-parse "$BRANCH")"
BUNDLE="$REPO_DIR/build/tmp/fetch-$(date '+%Y%m%d-%H%M%S').bundle"
mkdir -p build/tmp

cleanup() { $SSH "$SERVER" "rm -rf $REMOTE_DIR" 2>/dev/null || true; }
trap cleanup EXIT

info "服务器侧克隆（bare）"
$SSH "$SERVER" "rm -rf $REMOTE_DIR && git clone --bare --quiet '$REMOTE_URL' '$REMOTE_DIR/repo.git'" \
  || fail "服务器克隆失败"

REMOTE_TIP="$($SSH "$SERVER" "cd '$REMOTE_DIR/repo.git' && git rev-parse 'refs/heads/$BRANCH'")"
info "远端 $BRANCH = $REMOTE_TIP"

if [ "$REMOTE_TIP" = "$LOCAL_TIP" ]; then
  info "本地已是最新，无需拉取"
  git update-ref "refs/remotes/origin/$BRANCH" "$REMOTE_TIP"
  exit 0
fi

info "打包增量提交（排除本地已有 $LOCAL_TIP 的可达提交）"
$SSH "$SERVER" "cd '$REMOTE_DIR/repo.git' && git bundle create '$REMOTE_DIR/fetch.bundle' 'refs/heads/$BRANCH' --not '$LOCAL_TIP'" \
  || fail "服务器侧打包失败（前置提交本地不存在时会出现，改用全量包）"

info "回传 bundle"
$SCP "$SERVER:$REMOTE_DIR/fetch.bundle" "$BUNDLE" || fail "回传失败"

info "本地并入"
git bundle verify "$BUNDLE" >/dev/null || fail "bundle 校验失败"
git fetch --no-tags "$BUNDLE" "refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" || fail "本地 fetch 失败"
rm -f "$BUNDLE"

NEW_TIP="$(git rev-parse "refs/remotes/origin/$BRANCH")"
AHEAD="$(git rev-list --count "origin/$BRANCH..$BRANCH" 2>/dev/null || echo '?')"
BEHIND="$(git rev-list --count "$BRANCH..origin/$BRANCH" 2>/dev/null || echo '?')"

info "完成：origin/$BRANCH -> $NEW_TIP"
info "本地领先 $AHEAD 个提交，落后 $BEHIND 个提交"
