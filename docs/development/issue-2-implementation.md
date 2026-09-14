# Issue #2 implementation checkpoint

Branch: `feat/issue-2-app-shell`

## Implemented

- HarmonyOS Stage-model entry HAP scaffold.
- DevEco Studio 6.0.2 `modelVersion` project metadata.
- Build baseline: compile / compatible / target all pinned to HarmonyOS 6.0.0(20).
- Hvigor 6.0.2 and `@ohos/hvigor-ohos-plugin` 6.0.2 explicitly pinned.
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

The V0.1 app baseline is HarmonyOS 6.0.0(20). The compile SDK is intentionally also kept on API 20 so accidental use of newer APIs fails during development rather than on an older device.

`ContainerReader` is intentionally not used because the current official documentation marks it as API 26+. V0.1 uses API-20-compatible primitives such as `Navigation`, `Row` / `Column`, shared window size classes and `onAreaChange`. Container-level breakpoint refinement can be introduced later when the minimum supported API is raised or an API-compatible alternative is selected.

## Static gate

Run from the repository root:

`python scripts/validate_harmony_project.py`

The gate checks:

- API 20 compile / compatible / target baseline.
- Hvigor 6.0.2 plugin pinning.
- Phone + tablet device declaration.
- `Navigation` + `NavPathStack` root.
- central 600vp / 840vp breakpoint ownership.
- no API 26+ `ContainerReader` usage.
- required demo failure scenarios.

## Known limitation

This checkpoint has still not been compiled inside a local DevEco Studio installation from this environment. Static review cannot replace ArkTS compilation, Previewer, emulator/device validation, keyboard testing or signing validation.

## Next validation

1. Open the repository in DevEco Studio 6.0.2.
2. Let DevEco synchronize Hvigor / OHPM.
3. Configure automatic debug signing locally; do not commit certificate paths or passwords.
4. Run the static gate.
5. Build the `entry` module.
6. Run Phone and tablet previews/emulators around 600vp and 840vp.
7. Check rotation, split-screen and soft-keyboard behavior.
8. Record compile/runtime findings back on Issue #2 before merge.
