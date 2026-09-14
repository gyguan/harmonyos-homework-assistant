# Issue #2 implementation checkpoint

Branch: `feat/issue-2-app-shell`

## Implemented

- HarmonyOS Stage-model entry HAP scaffold.
- DevEco Studio 6.0.2 `modelVersion` project metadata.
- Build baseline: compile API 22, compatible/target API 20.
- Phone + tablet device declaration.
- One shared responsive resolver:
  - COMPACT <= 600vp
  - MEDIUM 600-840vp
  - EXPANDED > 840vp
- Student / Parent role shell with mock role switch.
- Compact bottom navigation and wide side navigation.
- Mock pages:
  - StudentTodayPage
  - StudyWorkspacePage
  - ParentDashboardPage
  - HomeworkImportPage
- Mock data for completed / in-progress / not-started / overdue assignments.
- Candidate Assignment low-confidence example and Source Evidence.

## Layout checkpoint

- Student Today: single column on Compact, list + next assignment on Expanded.
- Study Workspace: single column on Compact, 2 columns on Medium, 3 columns on Expanded.
- Parent Dashboard: stacked on Compact/Medium, progress + attention split on Expanded.
- Homework Import: stacked on Compact/Medium, source + candidate split on Expanded.

## Known limitations

This checkpoint was authored from the repository connector and has not yet been compiled inside a local DevEco Studio installation. The first local validation should therefore run `ohpm install`, project sync, and a debug build before merging. Any DevEco-generated wrapper metadata should be committed only after confirming it contains no local signing paths or secrets.

`ContainerReader` is intentionally not used in this first checkpoint because the current official documentation marks it as API 26+. The V0.1 runtime baseline remains HarmonyOS 6.0.0(20). Nested-container refinement can use compatible APIs or be added behind an API guard later.

## Next validation

1. Open the repository in DevEco Studio 6.0.2.
2. Let DevEco synchronize Hvigor / OHPM.
3. Configure automatic debug signing locally; do not commit certificate paths or passwords.
4. Build the `entry` module.
5. Run Phone and tablet previews/emulators at representative widths around 600vp and 840vp.
6. Record compile/runtime findings back on Issue #2 before merge.
