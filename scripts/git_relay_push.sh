#!/usr/bin/env bash
# 经云服务器中转推送到 GitHub。
#
# 为什么需要它：本机出网被代理限制 —— api.github.com 放行，但到 git 主机
# github.com 的 CONNECT 会被代理拒绝（502），直连则超时，因此 `git push` 走不通。
# 云服务器 192.144.143.141 能直连 github.com，所以打包成 bundle 由它代推。
#
# 用法（在 Git Bash 里跑，必须非沙箱执行 —— 沙箱读不到 SSH 私钥）：
#   bash scripts/git_relay_push.sh            # 推送当前分支到 origin 同名分支
#   bash scripts/git_relay_push.sh main       # 指定分支
#
# 前提：
#   - ~/.git-credentials 里已有可用的 https 凭据（classic token 需含 repo scope）
#   - 本地 remote-tracking（origin/main 等）是最新的；若不确定先跑 git fetch
#
# 原理：bundle 只打包 <远端..本地> 这一段提交，服务器 clone 后 fetch 再 push，
#       bundle 体积通常几百 KB，不需要上传整个仓库。

set -euo pipefail

REPO_DIR="D:/code/harmonyos-homework-assistant"
SERVER="ubuntu@192.144.143.141"
SSH_KEY="$HOME/.ssh/id_ed25519_tencent_lighthouse"
REMOTE_DIR="/tmp/git-relay-$$"
GIT_TOOLS="$(ls -d /c/Users/guang/.workbuddy/binaries/PortableGit/versions/*/usr/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$GIT_TOOLS" ] || GIT_TOOLS="/usr/bin"

BRANCH="${1:-$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)}"
REMOTE_URL="$(cd "$REPO_DIR" && git remote get-url origin)"

info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

cd "$REPO_DIR" || fail "仓库不存在: $REPO_DIR"

AHEAD="$(git rev-list --count "origin/$BRANCH..$BRANCH" 2>/dev/null || echo 0)"
[ "$AHEAD" -gt 0 ] || fail "$BRANCH 相对 origin/$BRANCH 没有新提交，无需推送"

BUNDLE="build/tmp/relay-$(date '+%Y%m%d-%H%M%S').bundle"
mkdir -p build/tmp
info "打包 $AHEAD 个提交 -> $BUNDLE"
git bundle create "$BUNDLE" "$BRANCH" --not "origin/$BRANCH"
git bundle list-heads "$BUNDLE" | grep -q "refs/heads/$BRANCH" || fail "bundle 缺少 refs/heads/$BRANCH"

REMOTE_BUNDLE="$REMOTE_DIR/push.bundle"
trap '"$GIT_TOOLS/ssh.exe" -i "$SSH_KEY" -o BatchMode=yes "$SERVER" "rm -rf $REMOTE_DIR" 2>/dev/null || true' EXIT

info "上传到服务器"
"$GIT_TOOLS/scp.exe" -i "$SSH_KEY" -o BatchMode=yes "$BUNDLE" "$SERVER:$REMOTE_DIR.bundle"
"$GIT_TOOLS/ssh.exe" -i "$SSH_KEY" -o BatchMode=yes "$SERVER" "mkdir -p $REMOTE_DIR && mv $REMOTE_DIR.bundle $REMOTE_BUNDLE"

info "服务器侧克隆并载入 bundle"
"$GIT_TOOLS/ssh.exe" -i "$SSH_KEY" -o BatchMode=yes "$SERVER" \
  "git clone --no-checkout --quiet '$REMOTE_URL' '$REMOTE_DIR/repo' && \
   cd '$REMOTE_DIR/repo' && \
   git fetch --quiet '$REMOTE_BUNDLE' 'refs/heads/$BRANCH:refs/heads/relay-$BRANCH' && \
   git rev-list --count 'origin/$BRANCH..relay-$BRANCH'"

# 凭据从本地 ~/.git-credentials 里取（不写死 token），形如 https://user:tok@github.com
CRED_LINE="$(grep -m1 '^https://[^@]*@github.com' "$HOME/.git-credentials" || true)"
[ -n "$CRED_LINE" ] || fail "~/.git-credentials 里没有 github.com 条目，无法在服务器侧认证"
AUTH_URL="$(echo "$REMOTE_URL" | sed -E 's#^https://#https://'"$(echo "$CRED_LINE" | sed -E 's#^https://([^@]*)@.*#\1#')"'@#')"

info "推送 $BRANCH 到 origin"
"$GIT_TOOLS/ssh.exe" -i "$SSH_KEY" -o BatchMode=yes "$SERVER" \
  "cd '$REMOTE_DIR/repo' && git push '$AUTH_URL' 'relay-$BRANCH:$BRANCH'"

info "同步本地 remote-tracking"
TIP="$(git rev-parse "$BRANCH")"
git update-ref "refs/remotes/origin/$BRANCH" "$TIP"
rm -f "$BUNDLE"

info "完成：origin/$BRANCH -> $TIP（推送 $AHEAD 个提交）"
