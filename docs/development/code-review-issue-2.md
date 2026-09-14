# Issue #2 pre-build code review

Fixed point: `main`

Review target: `feat/issue-2-app-shell` / PR #3

## Standards axis

### Resolved before local build

- Responsive breakpoints are owned by `ResponsiveContext`; feature pages do not define their own 600vp / 840vp thresholds.
- Root application shell uses `Navigation` bound to `NavPathStack`.
- V0.1 no longer references API 26+ `ContainerReader` in implementation guidance or code.
- Compile / compatible / target SDK are all pinned to HarmonyOS 6.0.0(20), so accidental use of newer APIs can fail early.
- Hvigor 6.0.2 and `@ohos/hvigor-ohos-plugin` 6.0.2 are explicitly pinned.
- Loading / empty / error states use one shared component instead of page-local duplicates.
- Phone and Pad keep different composition without device-model checks.

### Judgement calls accepted for scaffold stage

- AppShell still contains mock role and top-level route state. This is intentional for Issue #2 and should move toward domain/session services only after authentication and family context exist.
- Student and Parent primary navigation use custom bottom/side shells while `Navigation` is reserved as the root detail-navigation container. This is acceptable for the current four-page scaffold.

## Spec axis

### Implemented

- Stage-model ArkTS / ArkUI scaffold.
- Phone + tablet module declaration.
- Compact / Medium / Expanded responsive classes.
- Student / Parent shells and role switch mock.
- StudentTodayPage, StudyWorkspacePage, ParentDashboardPage, HomeworkImportPage.
- Expanded Study Workspace 3-column composition.
- Expanded Homework Import Source / Candidate split.
- Compact Parent Dashboard 2 x 2 KPI composition.
- Compact Homework Import staged Source -> Candidate flow.
- Compact Study Workspace separates Tutor from assignment content.
- Mock completed / in-progress / not-started / overdue assignments.
- Mock video + PDF resources.
- Low-confidence Candidate Assignment and Source Evidence.
- Reproducible loading / empty / error / offline / tutor-unavailable scenarios.
- Static invariant gate and GitHub workflow.

### Still requires DevEco/runtime evidence

- Actual ArkTS compile success.
- Hvigor/OHPM project synchronization.
- Debug signing and entry HAP build.
- Phone, tablet portrait, tablet landscape and split-screen rendering.
- Layout behavior around 600vp and 840vp.
- Soft-keyboard avoidance in Tutor input.
- Rotation/window-resize behavior.

## Merge decision

Keep PR #3 in Draft until the runtime evidence above is recorded. Static review is not sufficient to mark Issue #2 complete.
