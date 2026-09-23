#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def read(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        errors.append(f"missing: {path}")
        return ""
    return p.read_text(encoding="utf-8")

def require(ok: bool, msg: str) -> None:
    if not ok:
        errors.append(msg)

app = read("backend/src/main/resources/static/admin/js/app.js")
login_shell = read("backend/src/main/resources/static/admin/js/login-shell.js")
index = read("backend/src/main/resources/static/admin/index.html")
require("loginForm.addEventListener('submit', handleLogin)" in login_shell,
        "admin login submit handling must live in the isolated login shell")
require("publishAuthenticated(result.displayName)" in login_shell and
        "setView('admin')" in login_shell,
        "successful authentication must switch to the admin shell immediately")
require("window.__xiaobanAdminAuth = detail" in login_shell and
        "xiaoban-admin-authenticated" in login_shell,
        "login shell must publish authenticated state independently of business modules")
require("window.addEventListener('xiaoban-admin-authenticated'" in app and
        "window.__xiaobanAdminAuth" in app,
        "admin business module must initialize from the isolated authenticated state")
require("loginForm.addEventListener('submit'" not in app and
        "async function handleLogin" not in app,
        "business module must not own login submission")
require("login-shell.js?v=20260923-2" in index and
        "app.js?v=20260923-2" in index,
        "admin login shell and app module must be cache-busted together")
require("api.js?v=20260923-2" in login_shell and
        "api.js?v=20260923-2" in app and
        "voice-material.js?v=20260923-2" in app,
        "admin module dependency graph must use the same cache-bust version")
require("学生信息加载失败" in app,
        "initialization failure must remain visible in admin shell")
require('id="login-form"' in index, "login form must remain present")

if errors:
    print("ADMIN_LOGIN_GATE_FAIL")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)
print("ADMIN_LOGIN_GATE_PASS")
