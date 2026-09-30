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
        "FAST_WRONG", "SLOW_WRONG", "ToeicQuestionHistory", "questionHistories",
        "translation:string",
    ]:
        require(token in models, f"shared L/R model missing {token}")

    validator = read("entry/src/main/ets/toeic/content/ToeicContentValidator.ets")
    require("Part 7 evidence is required" in validator, "Part 7 evidence gate is missing")
    require("listening audioAssetId is required" in validator, "Listening audio gate is missing")
    require("listening transcript is required" in validator, "Listening transcript gate is missing")
    require("validateSentenceDrills" in validator and "translation is required" in validator,
            "sentence drill translation gate is missing")

    preset = read("entry/src/main/ets/toeic/content/PresetToeicContent.ets")
    week_one = read("entry/src/main/ets/toeic/content/ToeicWeekOneContent.ets")
    week_two = read("entry/src/main/ets/toeic/content/ToeicWeekTwoContent.ets")
    week_two_question_count = week_two.count("ToeicWeekTwoContent.q(")
    question_count = preset.count("new ToeicQuestion(") + week_one.count("new ToeicQuestion(") + week_two_question_count
    vocabulary_count = preset.count("new ToeicVocabularyItem(") + week_one.count("new ToeicVocabularyItem(")
    sentence_drill_count = week_one.count("new ToeicSentenceDrill(") + week_two.count("new ToeicSentenceDrill(")
    study_day_count = week_one.count("new ToeicStudyDay(") + week_two.count("new ToeicStudyDay(")
    require(question_count >= 190, f"expected >=190 reviewed Day 1-14 questions, found {question_count}")
    require(vocabulary_count >= 90, f"expected >=90 reviewed vocabulary items, found {vocabulary_count}")
    require(sentence_drill_count == 60, f"expected 60 sentence drills through Day 13, found {sentence_drill_count}")
    translated_drills = re.findall(
        r"new ToeicSentenceDrill\('([^']+)','[^']+','([^']+)'",
        week_one,
    )
    translated_drills += re.findall(
        r'new ToeicSentenceDrill\("([^"]+)","[^"]+","([^"]+)"',
        week_two,
    )
    require(len(translated_drills) == sentence_drill_count,
            "every TOEIC sentence drill must include a Chinese translation")
    for drill_id, translation in translated_drills:
        require(translation.strip(), f"{drill_id}: sentence drill translation is required")
    require(study_day_count == 14, f"expected 14 implemented study days, found {study_day_count}")
    require(week_two_question_count == 136,
            f"expected 36 week-two drills + 100 mock questions, found {week_two_question_count}")

    diagnostic_match = re.search(
        r"let ids:string\[\]=\[(.*?)\];",
        preset,
        flags=re.S,
    )
    require(diagnostic_match is not None, "diagnostic question id list is missing")
    diagnostic_ids = re.findall(r"'R-[^']+'", diagnostic_match.group(1))
    require(len(diagnostic_ids) == 12, f"expected 12 diagnostic questions, found {len(diagnostic_ids)}")

    question_ids = re.findall(r"new ToeicQuestion\('([^']+)'", preset + "\n" + week_one)
    question_ids += re.findall(r'ToeicWeekTwoContent\.q\("([^"]+)"', week_two)
    vocabulary_ids = re.findall(r"new ToeicVocabularyItem\('([^']+)'", preset + "\n" + week_one)
    sentence_ids = re.findall(r"new ToeicSentenceDrill\('([^']+)'", week_one)
    sentence_ids += re.findall(r'new ToeicSentenceDrill\("([^"]+)"', week_two)
    require(len(question_ids) == len(set(question_ids)), "TOEIC question ids must be unique")
    require(len(vocabulary_ids) == len(set(vocabulary_ids)), "TOEIC vocabulary ids must be unique")
    require(len(sentence_ids) == len(set(sentence_ids)), "TOEIC sentence drill ids must be unique")

    mock_part5_ids = re.findall(r'ToeicWeekTwoContent\.q\("(R-M1-P5-[^"]+)"', week_two)
    mock_part6_ids = re.findall(r'ToeicWeekTwoContent\.q\("(R-M1-P6-[^"]+)"', week_two)
    mock_part7_ids = re.findall(r'ToeicWeekTwoContent\.q\("(R-M1-P7-[^"]+)"', week_two)
    require(len(mock_part5_ids) == 30, f"Day 14 Part 5 must contain 30 questions, found {len(mock_part5_ids)}")
    require(len(mock_part6_ids) == 16, f"Day 14 Part 6 must contain 16 questions, found {len(mock_part6_ids)}")
    require(len(mock_part7_ids) == 54, f"Day 14 Part 7 must contain 54 questions, found {len(mock_part7_ids)}")
    require("new ToeicStudyDay(14" in week_two and "ToeicWeekTwoContent.mockQuestionIds()" in week_two,
            "Day 14 must map to the complete mock question set")


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
        "isMockDay(day:number)",
    ]
    for token in preset_api:
        require(token in preset, f"week-one catalog API missing: {token}")

    training = read("entry/src/main/ets/toeic/application/ToeicTrainingService.ets")
    require("PresetToeicContent.questionsForDay(studyDay)" in training,
            "adaptive daily queue must include the explicitly selected study day")
    require("studyDayQuestions(snapshot:ToeicLearningSnapshot, studyDay:number)" in training and
            "let planned=PresetToeicContent.questionsForDay(studyDay)" in training,
            "manual day entry must use a day-scoped queue")
    require("if (PresetToeicContent.isMockDay(studyDay)) return planned" in training,
            "full mock must preserve fixed question order and bypass remediation reordering")
    require("recoveryLimit=Math.min(4,limit)" in training,
            "daily queue must cap remediation so planned content still fits")
    require("containsQuestionId(selected,q.id)" in training and
            "selected.indexOf(q)" not in training,
            "daily queue must deduplicate by stable question id, not object identity")

    progress = read("entry/src/main/ets/toeic/data/ToeicProgressStore.ets")
    require("this.snapshot.currentDay=2" in progress,
            "diagnostic must count as Day 1 and advance to Day 2")
    require("MAX_AVAILABLE_STUDY_DAY:number=14" in progress,
            "progress must support the implemented Day 1-14 boundary")
    require("advanceProgress:boolean=true" in progress and
            "if (advanceProgress)" in progress,
            "review or preview sessions must be recordable without advancing currentDay")
    for token in [
        "attemptCount(questionId:string)", "wrongCount(questionId:string)",
        "history.attemptCount++", "if (!attempt.correct) history.wrongCount++",
        "Array.isArray(parsed.questionHistories)", "new ToeicQuestionHistory",
        "restored.schemaVersion=3",
    ]:
        require(token in progress, f"question history persistence missing: {token}")

    ui = read("entry/src/main/ets/toeic/ui/ToeicHomePage.ets")
    for token in ["VOCABULARY='VOCABULARY'", "SENTENCE='SENTENCE'", "DaySelector",
                  "DayButton", "VocabularyContent", "SentenceContent", "item.ipa", "Button('发音'",
                  "selectedStudyDay", "selectedDayTitle", "selectStudyDay(day:number)", "effectiveStudyDay()",
                  "this.DayButton(1);", "this.DayButton(7);", "this.DayButton(8);", "this.DayButton(14);",
                  ".onClick(()=>this.selectStudyDay(day))", "dailyQuestionsForDay(day)",
                  "'进入 Day '+this.selectedStudyDay+' 训练'", "currentAttemptCount", "currentWrongCount",
                  "'已做 '+this.currentAttemptCount+' 次'", "'错 '+this.currentWrongCount+' 次'",
                  "'译：'+item.translation"]:
        require(token in ui, f"week-one free-day UI missing: {token}")
    builder_sections = re.findall(
        r"(?ms)^\s*@Builder\s*\n\s*private .*?(?=^\s*@Builder|^\s*build\(\))",
        ui,
    )
    require(builder_sections, "TOEIC UI builders could not be identified")
    require(re.search(r"(?m)^\s+let\s+", "\n".join(builder_sections)) is None,
            "TOEIC @Builder bodies must not declare local let variables")
    require("QuestionContent(question:ToeicQuestion)" not in ui and
            "QuestionContent(questionIndex:number,questionId:string)" not in ui,
            "question renderer must not use question objects or array indexes as Builder state boundary")
    require("private QuestionContent()" in ui and
            "this.QuestionContent();" in ui,
            "question renderer must bind directly to explicit reactive snapshot state")
    for token in [
        "@State private currentQuestionId:string=''",
        "@State private currentStem:string=''",
        "@State private currentPassage:string=''",
        "@State private currentCorrectIndex:number=-1",
        "@State private currentAttemptCount:number=0",
        "@State private currentWrongCount:number=0",
        "private loadQuestion(index:number):boolean",
        "this.loadQuestion(0)",
        "this.loadQuestion(previousIndex)",
        "this.loadQuestion(nextIndex)",
        "private currentQuestionForAttempt():ToeicQuestion|null",
        "private sessionAttempt(questionId:string):ToeicQuestionAttempt|null",
        "question.id===this.currentQuestionId",
    ]:
        require(token in ui, f"reactive question snapshot missing: {token}")
    require("this.currentAttemptCount=this.viewModel.attemptCount(question.id)" in ui and
            "this.currentWrongCount=this.viewModel.wrongCount(question.id)" in ui,
            "question history badges must load from persisted history")
    require("this.currentAttemptCount++" in ui and
            "if (!attempt.correct) this.currentWrongCount++" in ui,
            "question history badges must update immediately after answering")
    for token in [
        "private previousQuestion():void",
        "Button('上一题'",
        ".enabled(this.currentIndex>0)",
        ".onClick(()=>this.previousQuestion())",
        ".enabled(this.answerLocked)",
        ".onClick(()=>this.nextQuestion())",
        "attempt===null?-1:attempt.selectedIndex",
        "this.answerCorrect=attempt===null?false:attempt.correct",
        "this.answerLocked=attempt!==null",
        "this.sessionAttempt(this.currentQuestionId)!==null",
    ]:
        require(token in ui, f"question navigation state restoration missing: {token}")
    require("if (!this.answerLocked) return;" in ui,
            "next question navigation must not skip unanswered questions")
    require("this.attempts.push(attempt)" in ui,
            "session attempts must remain the source of answered-question state")

    question_builder_match = re.search(
        r"(?ms)^\s*@Builder\s*\n\s*private QuestionContent\(\).*?(?=^\s*build\(\))",
        ui,
    )
    require(question_builder_match is not None, "QuestionContent builder could not be identified")
    question_builder = question_builder_match.group(0)
    require("this.questions[" not in question_builder,
            "QuestionContent must not render fields directly from class objects in the questions array")
    for token in [
        "this.currentStem", "this.currentPassage", "this.currentOptionA",
        "this.currentOptionB", "this.currentOptionC",
        "this.currentExplanation", "this.currentEvidence", "this.currentParaphrase",
    ]:
        require(token in question_builder, f"QuestionContent must render reactive snapshot field: {token}")
    require("index===this.currentCorrectIndex" in ui,
            "answer option styling must use reactive currentCorrectIndex snapshot")
    require("private optionBackground(index:number):string" in ui and
            "private optionBorder(index:number):string" in ui and
            "private optionText(index:number):string" in ui,
            "answer option styling must not depend on stale ToeicQuestion objects")
    require("this.activeSessionAdvancesProgress=day===this.progressCurrentDay" in ui,
            "only the real current progress day may advance currentDay")
    require("this.activeSessionAdvancesProgress=!this.progressDiagnosticCompleted" in ui,
            "Day 1 should advance only on the first diagnostic")
    require("else if (!snapshot.diagnosticCompleted)" not in ui,
            "diagnostic state must not hide the Day 1-7 selector or block free day entry")
    require("this.DaySelector();" in ui and
            "this.TodayCard();" in ui,
            "day selector and selected-day training card must always render from explicit state")
    require("private TodayCard()" in ui and
            "private HomeContent()" in ui and
            "TodayCard(snapshot:" not in ui and
            "HomeContent(snapshot:" not in ui,
            "selected-day home card must not depend on Builder object or selectedDay parameters")
    require("this.selectedDayTitle=plan.title" in ui and
            "this.selectedDayFocus=plan.focus" in ui,
            "selected day must load explicit plan snapshot fields")
    require("this.selectedStudyDay=this.progressCurrentDay" in ui and
            "this.loadStudyDay(this.selectedStudyDay)" in ui,
            "after completing the real current day the UI must follow and load the new currentDay")
    require("return this.activeSessionDay===14" in ui,
            "Day 14 must have an explicit mock-session boundary")
    require("完整模考过程中不显示对错与解析" in ui and
            "this.mode=mockSession?ToeicPageMode.MOCK_RESULT:ToeicPageMode.HOME" in ui,
            "mock mode must hide immediate feedback and show a result screen after completion")
    require("this.mockPart5Correct" in ui and "this.mockPart6Correct" in ui and "this.mockPart7Correct" in ui,
            "mock result must expose Part 5/6/7 breakdown")

    for token in [
        "@State private progressCurrentDay:number=1",
        "@State private progressDiagnosticCompleted:boolean=false",
        "@State private progressWeakSkill:string=ToeicSkill.PARAPHRASE",
        "@State private progressReviewCount:number=0",
        "@State private progressSlowCount:number=0",
        "@State private progressAnswered:number=0",
        "@State private progressCorrect:number=0",
        "@State private progressAccuracy:string='--'",
        "private loadProgressSnapshot():void",
        "this.progressCurrentDay=snapshot.currentDay",
        "this.progressDiagnosticCompleted=snapshot.diagnosticCompleted",
    ]:
        require(token in ui, f"explicit home progress snapshot missing: {token}")
    today_match = re.search(
        r"(?ms)^\s*@Builder\s*\n\s*private TodayCard\(\).*?(?=^\s*@Builder)",
        ui,
    )
    require(today_match is not None, "TodayCard builder could not be identified")
    today_builder = today_match.group(0)
    for token in [
        "this.selectedStudyDay", "this.selectedDayTitle", "this.selectedDayFocus",
        "this.selectedDayMinutes", "this.selectedDayVocabularyCount",
        "this.selectedDaySentenceCount",
    ]:
        require(token in today_builder, f"TodayCard must bind selected-day reactive state directly: {token}")

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
        f"mock=100(30/16/54), pronunciations={pronunciation_entry_count}"
    )


if __name__ == "__main__":
    main()
