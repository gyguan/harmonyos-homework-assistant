# HarmonyOS 本地测试依赖隔离

## 目标

正式 App 构建不得因为测试框架仓库不可用而失败。当前 `@ohos/hypium` 只服务
`entry/src/test` 下的本地确定性回归测试，不属于应用运行时或普通 HAP 构建依赖。

因此：

- `entry/oh-package.json5` **不常驻声明** `@ohos/hypium`；
- 普通 DevEco Studio Sync / Build 只安装正式构建依赖；
- 需要运行 ArkTS Local Test 时，通过专用脚本临时注入 Hypium；
- 无论安装或测试成功/失败，脚本都会在 `finally` 中恢复原始 manifest；
- 已下载到本机 `oh_modules` 的 Hypium 可继续作为本地缓存，不影响普通 Build。

## 运行本地测试

在工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_harmony_local_tests.ps1
```

如需覆盖率：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_harmony_local_tests.ps1 -Coverage
```

脚本执行流程：

1. 保存 `entry/oh-package.json5` 原文；
2. 临时加入 `@ohos/hypium@1.0.19`；
3. 在 `entry` 目录执行 `ohpm install`；
4. 执行 `hvigorw test -p module=entry`；
5. 恢复原始 `entry/oh-package.json5`。

## 约束

不要为了新增测试而把 Hypium 重新常驻加入 `entry/oh-package.json5`。
`scripts/validate_harmony_project.py` 会检查这一约束，避免测试网络依赖再次阻塞普通构建。
