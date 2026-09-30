from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOEIC = ROOT / "entry/src/main/ets/toeic"


def fail(message: str) -> None:
    raise SystemExit(f"[toeic-coach] FAIL: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read(path: str) -> str:
    target = ROOT / path
    require(target.exists(), f"missing {path}")
    return target.read_text(encoding="utf-8")


def main() -> None:
    require(TOEIC.exists(), "TOEIC module directory is missing")
    sources = "\\n".join(
        p.read_text(encoding="utf-8")
        for p in TOEIC.rglob("*.ets")
    )

    forbidden = [
        "HomeworkStore",
        "AssignmentRepository",
        "DefaultAssignmentRepository",
        "PracticeRepository",
        "DefaultPracticeRepository",
        "StudentProfile",
        "FamilyContextRepository",
    ]
    for token in forbidden:
        require(token not in sources, f"TOEIC module must not depend on {token}")

    models = read("entry/src/main/ets/toeic/domain/ToeicModels.ets")
    for token in [
        "LISTENING", "READING", "PART_1", "PART_2", "PART_3", "PART_4",
        "PART_5", "PART_6", "PART_7", "FAST_CORRECT", "SLOW_CORRECT",
        "FAST_WRONG", "SLOW_WRONG",
    ]:
        require(token in models, f"shared L/R model missing {token}")

    validator = read("entry/src/main/ets/toeic/content/ToeicContentValidator.ets")
    require("Part 7 evidence is required" in validator, "Part 7 evidence gate is missing")
    require("listening audioAssetId is required" in validator, "Listening audio gate is missing")
    require("listening transcript is required" in validator, "Listening transcript gate is missing")

    preset = read("entry/src/main/ets/toeic/content/PresetToeicContent.ets")
    question_count = preset.count("new ToeicQuestion(")
    vocabulary_count = preset.count("new ToeicVocabularyItem(")
    require(question_count >= 18, f"expected >=18 reviewed starter questions, found {question_count}")
    require(vocabulary_count >= 30, f"expected >=30 starter vocabulary items, found {vocabulary_count}")

    diagnostic_match = re.search(
        r"let ids:string\[\]=\[(.*?)\];",
        preset,
        flags=re.S,
    )
    require(diagnostic_match is not None, "diagnostic question id list is missing")
    diagnostic_ids = re.findall(r"'R-[^']+'", diagnostic_match.group(1))
    require(len(diagnostic_ids) == 12, f"expected 12 diagnostic questions, found {len(diagnostic_ids)}")

    shell = read("entry/src/main/ets/pages/AppShell.ets")
    require("TOEIC = 'TOEIC'" in shell, "parent primary TOEIC route is missing")
    require("ToeicHomePage" in shell, "TOEIC home is not connected to AppShell")
    require("@State private toeic" not in shell.lower(), "AppShell must not own TOEIC business state")

    ability = read("entry/src/main/ets/entryability/EntryAbility.ets")
    require("ToeicModuleBootstrap.initialize" in ability, "TOEIC progress bootstrap is missing")

    standard = read("docs/product/toeic-coach-content-standard.md")
    for phrase in [
        "内容准确性优先于题量",
        "Part 7",
        "Listening",
        "FAST_CORRECT",
        "SLOW_CORRECT",
    ]:
        require(phrase in standard, f"content standard missing: {phrase}")

    print(
        f"[toeic-coach] PASS: questions={question_count}, "
        f"diagnostic={len(diagnostic_ids)}, vocabulary={vocabulary_count}"
    )


if __name__ == "__main__":
    main()
