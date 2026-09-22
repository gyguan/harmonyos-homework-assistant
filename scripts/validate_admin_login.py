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
index = read("backend/src/main/resources/static/admin/index.html")
require("LoginState = Object.freeze" in app, "admin login must use explicit state")
require("AUTHENTICATING" in app and "INITIALIZING" in app and "READY" in app, "login states must distinguish auth and initialization")
require("showAdminShell(result.displayName)" in app, "admin shell must become visible immediately after authentication")
require("await initializeAdmin()" in app, "student loading must be a separate initialization step")
require("setView('admin')" in app, "authenticated state must switch to admin view")
require("学生信息加载失败" in app, "initialization failure must remain visible in admin shell")
require('id="login-form"' in index, "login form must remain present")

if errors:
    print("ADMIN_LOGIN_GATE_FAIL")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)
print("ADMIN_LOGIN_GATE_PASS")
