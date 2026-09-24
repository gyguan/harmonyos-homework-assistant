#!/usr/bin/env python3
from pathlib import Path
import sys
import re

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
        "admin business module must initialize from isolated authenticated state")
require("async function handleLogin" not in app,
        "business module must not own login submission")
login_match = re.search(r"login-shell\\.js\\?v=([0-9-]+)", index)
app_match = re.search(r"app\\.js\\?v=([0-9-]+)", index)
require(login_match is not None and app_match is not None and
        login_match.group(1) == app_match.group(1),
        "admin login shell and app module must be cache-busted together")
cache_version = login_match.group(1) if login_match is not None else ""
require(f"api.js?v={cache_version}" in login_shell and
        f"api.js?v={cache_version}" in app and
        f"voice-material.js?v={cache_version}" in app and
        f"voice-management-view.js?v={cache_version}" in app,
        "admin module dependency graph must use the same cache-bust version")
require('id="login-form"' in index and 'id="admin-view"' in index,
        "login and admin shells must remain explicit")

if errors:
    print("ADMIN_LOGIN_GATE_FAIL")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)
print("ADMIN_LOGIN_GATE_PASS")
