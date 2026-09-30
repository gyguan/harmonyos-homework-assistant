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
    week_one = read("entry/src/main/ets/toeic/content/ToeicWeekOneContent.ets")
    question_count = preset.count("new ToeicQuestion(") + week_one.count("new ToeicQuestion(")
    vocabulary_count = preset.count("new ToeicVocabularyItem(") + week_one.count("new ToeicVocabularyItem(")
    sentence_drill_count = week_one.count("new ToeicSentenceDrill(")
    study_day_count = week_one.count("new ToeicStudyDay(")
    require(question_count >= 54, f"expected >=54 reviewed week-one questions, found {question_count}")
    require(vocabulary_count >= 90, f"expected >=90 week-one vocabulary items, found {vocabulary_count}")
    require(sentence_drill_count == 30, f"expected 30 sentence drills, found {sentence_drill_count}")
    require(study_day_count == 7, f"expected 7 study days, found {study_day_count}")

    diagnostic_match = re.search(
        r"let ids:string\[\]=\[(.*?)\];",
        preset,
        flags=re.S,
    )
    require(diagnostic_match is not None, "diagnostic question id list is missing")
    diagnostic_ids = re.findall(r"'R-[^']+'", diagnostic_match.group(1))
    require(len(diagnostic_ids) == 12, f"expected 12 diagnostic questions, found {len(diagnostic_ids)}")

    question_ids = re.findall(r"new ToeicQuestion\('([^']+)'", preset + "\n" + week_one)
    vocabulary_ids = re.findall(r"new ToeicVocabularyItem\('([^']+)'", preset + "\n" + week_one)
    sentence_ids = re.findall(r"new ToeicSentenceDrill\('([^']+)'", week_one)
    require(len(question_ids) == len(set(question_ids)), "TOEIC question ids must be unique")
    require(len(vocabulary_ids) == len(set(vocabulary_ids)), "TOEIC vocabulary ids must be unique")
    require(len(sentence_ids) == len(set(sentence_ids)), "TOEIC sentence drill ids must be unique")

    pronunciation = read("entry/src/main/ets/toeic/content/ToeicPronunciationCatalog.ets")
    pronunciation_entry_count = pronunciation.count("new ToeicPronunciationEntry(")
    require(pronunciation_entry_count == vocabulary_count,
            f"every TOEIC vocabulary item must have pronunciation metadata: {pronunciation_entry_count}/{vocabulary_count}")
    require("V-033','/ˈrɛzəˌmeɪ/'" in pronunciation and "'résumé'" in pronunciation,
            "resume noun pronunciation must be disambiguated")
    require("V-014','/ˈriːfʌnd/ n. · /ˌriːˈfʌnd/ v.'" in pronunciation,
            "refund noun/verb pronunciation distinction is required")
    require("V-038','/ˈtrænsfɝː/'" in pronunciation,
            "transfer en-US pronunciation is required")
    require("V-051','/ˈɛstəmət/ n. · /ˈɛstəmeɪt/ v.'" in pronunciation,
            "estimate noun/verb pronunciation distinction is required")
    require("V-082','/ʌpˈɡreɪd/ v. · /ˈʌpɡreɪd/ n.'" in pronunciation,
            "upgrade noun/verb pronunciation distinction is required")

    pronunciation_service = read("entry/src/main/ets/toeic/application/ToeicPronunciationService.ets")
    for token in ["@kit.CoreSpeechKit", "SystemCapability.AI.TextToSpeech", "language: 'en-US'",
                  "person: 8", "downloadVoice", "queueMode", "ToeicPronunciationStatus"]:
        require(token in pronunciation_service, f"TOEIC pronunciation service missing: {token}")

    syscap = read("syscap.json")
    require(syscap.count("SystemCapability.AI.TextToSpeech") >= 2,
            "TextToSpeech capability must be associated in development and production")

    preset_api = [
        "questionsForDay(day:number)",
        "vocabularyForDay(day:number)",
        "sentenceDrillsForDay(day:number)",
        "studyDay(day:number)",
    ]
    for token in preset_api:
        require(token in preset, f"week-one catalog API missing: {token}")

    training = read("entry/src/main/ets/toeic/application/ToeicTrainingService.ets")
    require("PresetToeicContent.questionsForDay(studyDay)" in training,
            "daily queue must include the explicitly selected study day")
    require("recoveryLimit=Math.min(4,limit)" in training,
            "daily queue must cap remediation so planned content still fits")
    require("containsQuestionId(selected,q.id)" in training and
            "selected.indexOf(q)" not in training,
            "daily queue must deduplicate by stable question id, not object identity")

    progress = read("entry/src/main/ets/toeic/data/ToeicProgressStore.ets")
    require("this.snapshot.currentDay=2" in progress,
            "diagnostic must count as Day 1 and advance to Day 2")
    require("MAX_AVAILABLE_STUDY_DAY:number=7" in progress,
            "week-one progress must stop at the currently implemented day boundary")
    require("advanceProgress:boolean=true" in progress and
            "if (advanceProgress)" in progress,
            "review or preview sessions must be recordable without advancing currentDay")

    ui = read("entry/src/main/ets/toeic/ui/ToeicHomePage.ets")
    for token in ["VOCABULARY='VOCABULARY'", "SENTENCE='SENTENCE'", "WeekPlanCard",
                  "VocabularyContent", "SentenceContent", "item.ipa", "Button('发音'",
                  "selectedStudyDay", "selectStudyDay(day:number)", "effectiveStudyDay()",
                  ".onClick(()=>this.selectStudyDay(plan.day))", "dailyQuestionsForDay(day)"]:
        require(token in ui, f"week-one learning UI missing: {token}")
    builder_sections = re.findall(
        r"(?ms)^\s*@Builder\s*\n\s*private .*?(?=^\s*@Builder|^\s*build\(\))",
        ui,
    )
    require(builder_sections, "TOEIC UI builders could not be identified")
    require(re.search(r"(?m)^\s+let\s+", "\n".join(builder_sections)) is None,
            "TOEIC @Builder bodies must not declare local let variables")
    require("QuestionContent(question:ToeicQuestion)" not in ui,
            "question renderer must not use ToeicQuestion class object as Builder state boundary")
    require("QuestionContent(questionIndex:number,questionId:string)" in ui and
            "this.QuestionContent(this.currentIndex,this.questions[this.currentIndex].id)" in ui,
            "question renderer must refresh from primitive index/id state")
    require("this.activeSessionAdvancesProgress=day===this.viewModel.snapshot().currentDay" in ui,
            "only the real current progress day may advance currentDay")
    require("if (advanceProgress) this.selectedStudyDay=0" in ui,
            "after completing the real current day the UI must follow the new currentDay")

    shell = read("entry/src/main/ets/pages/AppShell.ets")
    require("TOEIC = 'TOEIC'" in shell, "parent primary TOEIC route is missing")
    require("ToeicHomePage" in shell, "TOEIC home is not connected to AppShell")
    require("@state private toeic" not in shell.lower(), "AppShell must not own TOEIC business state")

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
        f"diagnostic={len(diagnostic_ids)}, vocabulary={vocabulary_count}, "
        f"sentences={sentence_drill_count}, days={study_day_count}, "
        f"pronunciations={pronunciation_entry_count}"
    )


if __name__ == "__main__":
    main()
