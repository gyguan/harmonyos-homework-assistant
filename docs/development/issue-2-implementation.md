# Issue #2 implementation checkpoint

Branch: `feat/issue-2-app-shell`

## Implemented

- HarmonyOS Stage-model entry HAP scaffold.
- Current DevEco Studio 26.0.0 toolchain-compatible project metadata.
- Build baseline:
  - compile SDK: `26.0.0`
  - compatible SDK: `6.0.0(20)`
  - target SDK: unset (follow the locally verified DevEco configuration)
- Project model version: `5.0.0` in both `hvigor/hvigor-config.json5` and root `oh-package.json5`.
- Hvigor 6.26.4 and `@ohos/hvigor-ohos-plugin` 6.26.4 explicitly pinned.
- Phone + tablet device declaration.
- One shared responsive resolver:
  - COMPACT <= 600vp
  - MEDIUM 600-840vp
  - EXPANDED > 840vp
- `Navigation` root bound to a shared `NavPathStack`.
- Student / Parent role shell with mock role switch.
- Compact bottom navigation and wide side navigation.
- Mock pages:
  - StudentTodayPage
  - StudyWorkspacePage
  - ParentDashboardPage
  - HomeworkImportPage
- Mock data for completed / in-progress / not-started / overdue assignments.
- Candidate Assignment low-confidence example and Source Evidence.
- Reproducible demo scenarios:
  - normal
  - loading
  - empty
  - error
  - offline cached work
  - AI Tutor unavailable
- Shared loading / empty / error state component.
- Static project release gate in `scripts/validate_harmony_project.py` and GitHub Actions.
- Two-axis pre-build review recorded in `docs/development/code-review-issue-2.md`.

## Layout checkpoint

- Student Today: single column on Compact, list + next assignment on Expanded.
- Study Workspace:
  - Compact: assignment workspace and AI Tutor are separate surfaces.
  - Medium: 2 columns.
  - Expanded: 3 columns (task / study content / tutor).
- Parent Dashboard:
  - Compact: 2 x 2 KPI layout.
  - Expanded: progress + attention split.
- Homework Import:
  - Compact: source input -> candidate result staged flow.
  - Medium: stacked source + candidates.
  - Expanded: source + candidate split.

## Compatibility decisions

The locally verified DevEco Studio 26.0.0 configuration uses `compileSdkVersion: 26.0.0`, keeps `compatibleSdkVersion: 6.0.0(20)`, leaves `targetSdkVersion` unset, and requires project `modelVersion: 5.0.0`.

`ContainerReader` is intentionally not used because it requires API 26+. V0.1 runtime-compatible code continues to use API-20-compatible primitives such as `Navigation`, `Row` / `Column`, shared window size classes and `onAreaChange`.

## Static gate

Run from the repository root:

`python scripts/validate_harmony_project.py`

The gate checks:

- compile SDK 26.0.0 with compatible baseline 6.0.0(20) and no explicit target SDK override.
- project modelVersion 5.0.0.
- Hvigor 6.26.4 plugin pinning.
- Phone + tablet device declaration.
- `Navigation` + `NavPathStack` root.
- central 600vp / 840vp breakpoint ownership.
- no API 26+ `ContainerReader` usage in V0.1 runtime-compatible code.
- required demo failure scenarios.

## Known limitation

This checkpoint has still not completed a successful local DevEco Studio build. Static review cannot replace ArkTS compilation, Previewer, emulator/device validation, keyboard testing or signing validation.

## Next validation

1. Pull the latest `feat/issue-2-app-shell` branch.
2. Reopen the repository root in DevEco Studio 26.0.0.
3. Let DevEco synchronize Hvigor / OHPM.
4. Configure automatic debug signing locally; do not commit certificate paths or passwords.
5. Run the static gate.
6. Build the `entry` module.
7. Run Phone and tablet previews/emulators around 600vp and 840vp.
8. Check rotation, split-screen and soft-keyboard behavior.
9. Record compile/runtime findings back on Issue #2 before merge.
