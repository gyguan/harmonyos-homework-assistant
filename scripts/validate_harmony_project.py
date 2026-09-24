#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: str) -> str:
    file = ROOT / path
    require(file.exists(), f"missing required file: {path}")
    return file.read_text(encoding="utf-8") if file.exists() else ""


# Toolchain/runtime contract: these values are locally compile-verified and must not drift as a
# side effect of product refactoring.
build_profile = read("build-profile.json5")
hvigor_config = read("hvigor/hvigor-config.json5")
oh_package = read("oh-package.json5")
entry_oh_package = read("entry/oh-package.json5")
module_config = read("entry/src/main/module.json5")
backend_pom = read("backend/pom.xml")

require('"compileSdkVersion": "26.0.0"' in build_profile,
        "compileSdkVersion must match the DevEco Studio 26.0.0 toolchain")
require('"compatibleSdkVersion": "6.0.0(20)"' in build_profile,
        "compatibleSdkVersion must keep the runtime baseline at HarmonyOS 6.0.0(20)")
require('"targetSdkVersion": "26.0.0"' in build_profile,
        "targetSdkVersion must explicitly target HarmonyOS 26.0.0 API behavior")
require('"modelVersion": "5.0.0"' in hvigor_config, "Hvigor modelVersion must remain 5.0.0")
require('"modelVersion": "5.0.0"' in oh_package, "OHPM modelVersion must remain 5.0.0")
require('"version": "1.0.0"' in entry_oh_package,
        "entry module package version must use stable SemVer form")
require('"hvigorVersion": "6.26.4"' in hvigor_config, "Hvigor version must remain pinned to 6.26.4")
require('"@ohos/hvigor-ohos-plugin": "6.26.4"' in hvigor_config,
        "Hvigor OHOS plugin must remain pinned to 6.26.4")
require('"phone"' in module_config and '"tablet"' in module_config,
        "entry module must continue to support both phone and tablet")

# Durable application boundaries. Do not assert V1 page names, builders, route enums, Store
# methods, or responsive breakpoints here; specialized behavior/architecture gates cover them.
required_paths = [
    "entry/src/main/ets/entryability/EntryAbility.ets",
    "entry/src/main/ets/domain/model/HomeworkModels.ets",
    "entry/src/main/ets/domain/model/PersistenceModels.ets",
    "entry/src/main/ets/domain/port/HomeworkPersistence.ets",
    "entry/src/main/ets/domain/port/HomeworkTextExtractor.ets",
    "entry/src/main/ets/domain/port/HomeworkAssignmentParser.ets",
    "entry/src/main/ets/domain/service/AssignmentStateMachine.ets",
    "entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkPersistence.ets",
    "entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets",
    "backend/src/main/resources/db/migration/V1__core_schema.sql",
]
for path in required_paths:
    require((ROOT / path).exists(), f"missing durable project boundary: {path}")

entry_ability = read("entry/src/main/ets/entryability/EntryAbility.ets")
local_bootstrap = read("entry/src/main/ets/data/local/HomeworkLocalBootstrap.ets")
persistence_port = read("entry/src/main/ets/domain/port/HomeworkPersistence.ets")
persistence_adapter = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkPersistence.ets")
core_ocr = read("entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets")
state_machine = read("entry/src/main/ets/domain/service/AssignmentStateMachine.ets")
parent_dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
remote_submission = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")

require("interface HomeworkPersistence" in persistence_port,
        "local persistence must stay behind HomeworkPersistence")
require("class PreferencesHomeworkPersistence" in persistence_adapter and "@kit.ArkData" in persistence_adapter,
        "ArkData Preferences must remain an infrastructure adapter")
require("class AssignmentStateMachine" in state_machine and "canTransition" in state_machine,
        "assignment transition rules must remain centralized")
require("class CoreVisionHomeworkTextExtractor" in core_ocr and "@kit.CoreVisionKit" in core_ocr,
        "production OCR must remain behind the Core Vision adapter")
require("PreferencesHomeworkPersistence" in entry_ability and "CoreVisionHomeworkTextExtractor" in entry_ability,
        "EntryAbility must compose production adapters")
require("HomeworkStore" not in entry_ability and "HomeworkLocalBootstrap.instance.initialize" in entry_ability,
        "EntryAbility must initialize local homework state through the data/local bootstrap boundary")
require("HomeworkStore.instance.initialize(persistence)" in local_bootstrap,
        "HomeworkLocalBootstrap must remain the only composition boundary that initializes HomeworkStore")
require("MockHomeworkTextExtractor" not in entry_ability and "MockHomeworkAssignmentParser" not in entry_ability,
        "production composition root must not use mock import adapters")

# DevEco-only compile regressions that are not covered by the Linux static gate.
require("sys.symbol.add_circle" not in parent_dashboard,
        "Parent Dashboard must not use unsupported sys.symbol.add_circle on the pinned HarmonyOS toolchain")
require("sys.symbol.plus_square" in parent_dashboard,
        "Parent Dashboard extracurricular action must use a compile-verified system symbol")
require("SUBMISSION_NETWORK_ERROR" in remote_submission and
        "response = await client.request(" in remote_submission,
        "Remote submission upload must explicitly handle exceptions from http client.request")
# Production/test boundary: deterministic fixtures and issue-specific test IDs must not ship in
# src/main. Hypium is an opt-in Local Test dependency and must not block ordinary app builds.
test_suite = read("entry/src/test/List.test.ets")
local_test_runner = read("scripts/run_harmony_local_tests.ps1")
require("@ohos/hypium" not in entry_oh_package,
        "Hypium must not be a permanent entry dependency; ordinary app builds must stay network-independent")
require("@ohos/hypium" in local_test_runner and "1.0.19" in local_test_runner and
        "hvigorw test" in local_test_runner and "finally" in local_test_runner,
        "optional Harmony Local Test runner must inject Hypium only for the test session and restore the manifest")
require("Issue245ChatReconstructionFixture" in test_suite and
        "Issue246HomeworkUnderstandingFixture" in test_suite and
        "Issue247FullClosureFixture" in test_suite,
        "deterministic homework-import regressions must be registered in the ArkTS test suite")

production_ets_root = ROOT / "entry/src/main/ets"
for production_file in production_ets_root.rglob("*.ets"):
    relative = production_file.relative_to(ROOT).as_posix()
    source = production_file.read_text(encoding="utf-8")
    require("Fixture" not in production_file.name,
            f"test fixture must not live in production sources: {relative}")
    require("issue244-fixture" not in source and "issue245-fixture" not in source and
            "issue246-fixture" not in source and "issue247-fixture" not in source,
            f"production behavior must not depend on issue fixture IDs: {relative}")


# V2 parent-import architecture: Feature pages are UI composition only; business access goes
# through ViewModels. Parent-import route actions live outside AppShell.
for page_path in [
    "entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets",
]:
    page_source = read(page_path)
    require("Service.instance" not in page_source,
            f"V2 Feature page must not call application service singleton directly: {page_path}")
    require("DefaultFamilyContextRepository.instance" not in page_source,
            f"V2 Feature page must not call repository singleton directly: {page_path}")

app_shell = read("entry/src/main/ets/pages/AppShell.ets")
parent_import_navigator = read("entry/src/main/ets/app/navigation/ParentImportNavigator.ets")
for legacy_shell_method in [
    "private openParentImport(",
    "private openParentImportInbox(",
    "private openParentImportBatch(",
    "private openParentCapture(",
    "private openParentSourceProfile(",
    "private openParentCaptureSpike(",
    "private openParentImportConfirmation(",
]:
    require(legacy_shell_method not in app_shell,
            f"AppShell must not regain parent-import route operation: {legacy_shell_method}")
require("class ParentImportNavigator" in parent_import_navigator,
        "parent-import navigation operations must stay in dedicated navigator")

for retired_capture_path in [
    "entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets",
    "entry/src/main/ets/domain/port/HomeworkCaptureRuntime.ets",
    "entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkCaptureSessionPersistence.ets",
]:
    require(not (ROOT / retired_capture_path).exists(),
            f"retired screen-capture code must not reappear: {retired_capture_path}")

# Keep the backend intentionally lightweight during the family-product refactor.
for forbidden_dependency in ["spring-data-redis", "spring-kafka", "spring-cloud-gateway", "camunda", "flowable"]:
    require(forbidden_dependency not in backend_pom,
            f"backend must not introduce heavy infrastructure dependency: {forbidden_dependency}")

if errors:
    print("STATIC_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STATIC_GATE_PASS")
