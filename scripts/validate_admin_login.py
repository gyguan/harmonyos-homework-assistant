#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


bootstrap = read("backend/src/main/java/com/xiaoban/homework/bootstrap/LocalBootstrap.java")
config = read("backend/src/main/resources/application.yml")
index = read("backend/src/main/resources/static/admin/index.html")
app = read("backend/src/main/resources/static/admin/js/app.js")

require("app.bootstrap.reset-password:false" in bootstrap,
        "bootstrap password recovery must be opt-in and default false")
require("if (resetPassword)" in bootstrap and
        "existing.passwordHash = encoder.encode(password)" in bootstrap,
        "explicit bootstrap recovery must reset only the configured existing account")
require("BOOTSTRAP_RESET_PASSWORD:false" in config,
        "application config must expose BOOTSTRAP_RESET_PASSWORD with a safe false default")
require('id="login-submit"' in index and 'id="login-status"' in index,
        "admin login page must expose visible progress controls")
require("正在验证账号" in app and "登录成功，正在加载学生信息" in app,
        "admin login must distinguish authentication from post-login loading")
require("error.status === 401" in app and "已有账号不会在重启时被自动覆盖" in app,
        "admin login must explain persisted-account default-password behavior")
require("账号验证成功，但加载学生信息失败" in app,
        "admin login must surface post-auth student loading failures instead of looking stuck")

if errors:
    print("ADMIN_LOGIN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ADMIN_LOGIN_GATE_PASS")
