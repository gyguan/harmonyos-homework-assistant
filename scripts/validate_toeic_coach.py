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
    require("validateQuestionTranslations" in validator and
            "Chinese translation is required for Day 1-13 training" in validator and
            "translated option count must match question options" in validator,
            "question translation content gate is missing")

    preset = read("entry/src/main/ets/toeic/content/PresetToeicContent.ets")
    week_one = read("entry/src/main/ets/toeic/content/ToeicWeekOneContent.ets")
    week_two = read("entry/src/main/ets/toeic/content/ToeicWeekTwoContent.ets")
    week_three = read("entry/src/main/ets/toeic/content/ToeicWeekThreeContent.ets")
    expansion = read("entry/src/main/ets/toeic/content/ToeicVocabularyExpansion.ets")
    extra_diagnostic = read("entry/src/main/ets/toeic/content/ToeicStandardDiagnosticContent.ets")
    week_two_question_count = week_two.count("ToeicWeekTwoContent.q(")
    week_three_question_count = week_three.count("ToeicWeekThreeContent.q(")
    question_count = (preset.count("new ToeicQuestion(") + week_one.count("new ToeicQuestion(") +
                      week_two_question_count + week_three_question_count +
                      extra_diagnostic.count("new ToeicQuestion("))
    vocabulary_count = (preset.count("new ToeicVocabularyItem(") +
                        week_one.count("new ToeicVocabularyItem(") +
                        expansion.count("new ToeicVocabularyItem("))
    sentence_drill_count = (week_one.count("new ToeicSentenceDrill(") +
                            week_two.count("new ToeicSentenceDrill(") +
                            week_three.count("new ToeicSentenceDrill("))
    study_day_count = (week_one.count("new ToeicStudyDay(") +
                       week_two.count("new ToeicStudyDay(") +
                       week_three.count("new ToeicStudyDay("))
    require(question_count >= 354, f"expected >=354 reviewed Day 1-21 questions, found {question_count}")
    require(vocabulary_count >= 90, f"expected >=90 reviewed vocabulary items, found {vocabulary_count}")
    require(sentence_drill_count == 70, f"expected 70 sentence drills through Day 21, found {sentence_drill_count}")
    translated_drills = re.findall(
        r"new ToeicSentenceDrill\('([^']+)','[^']+','([^']+)'",
        week_one,
    )
    translated_drills += re.findall(
        r'new ToeicSentenceDrill\("([^"]+)","[^"]+","([^"]+)"',
        week_two,
    )
    translated_drills += re.findall(
        r'new ToeicSentenceDrill\("([^"]+)","[^"]+","([^"]+)"',
        week_three,
    )
    require(len(translated_drills) == sentence_drill_count,
            "every TOEIC sentence drill must include a Chinese translation")
    for drill_id, translation in translated_drills:
        require(translation.strip(), f"{drill_id}: sentence drill translation is required")
    require(study_day_count == 21, f"expected 21 implemented study days, found {study_day_count}")
    require(week_two_question_count == 136,
            f"expected 36 week-two drills + 100 mock questions, found {week_two_question_count}")
    require(week_three_question_count == 164,
            f"expected 64 week-three sprint questions + 100 second-mock questions, found {week_three_question_count}")
    require(re.search(r"\[[^\]\n]*\bnull\b[^\]\n]*\]", week_three) is None,
            "week-three question options must be concrete strings, never null placeholders")
    require('["9:30","10:00","10:15","10:30"],1' in week_three,
            "Day 17 sample answer mapping must keep 10:00 at option index 1")
    require('["11:30 A.M.","12:20 P.M.","1:00 P.M.","4:00 P.M."],2' in week_three,
            "Day 17 sample answer mapping must keep 1:00 P.M. at option index 2")
    require('["$0.20","$1.15","$2.00","$0.95"],3' in week_three,
            "Day 19 sample answer mapping must keep $0.95 at option index 3")

    translation_week_one = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationWeekOneCatalog.ets")
    translation_week_two = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationWeekTwoCatalog.ets")
    translation_catalog = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationCatalog.ets")
    translation_ids = re.findall(r"new ToeicQuestionTranslation\('([^']+)'", translation_week_one + "\n" + translation_week_two)
    translation_ids += re.findall(r'new ToeicQuestionTranslation\("([^"]+)"', translation_week_two)
    require(len(translation_ids) == 84,
            f"Day 1-13 must have exactly 84 question translations, found {len(translation_ids)}")
    require(len(translation_ids) == len(set(translation_ids)),
            "TOEIC question translation ids must be unique")
    require(not any(question_id.startswith("R-M1-") or question_id.startswith("R-M2-") for question_id in translation_ids),
            "full mock questions must not have Chinese translations")
    require("ToeicQuestionTranslationWeekOneCatalog.items().concat(ToeicQuestionTranslationWeekTwoCatalog.items())" in translation_catalog,
            "question translation catalog must aggregate week-one and week-two translations")

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
    question_ids += re.findall(r'ToeicWeekThreeContent\.q\("([^"]+)"', week_three)
    question_ids += re.findall(r'new ToeicQuestion\("(R-DX-[^"]+)"', extra_diagnostic)
    require(len(re.findall(r'new ToeicQuestion\("(R-DX-[^"]+)"', extra_diagnostic)) == 12,
            "standard diagnostic must have 12 unique extra questions")
    require(len(re.findall(r'new ToeicQuestion\("R-DX-P5-', extra_diagnostic)) == 6 and
            len(re.findall(r'new ToeicQuestion\("R-DX-P6-', extra_diagnostic)) == 2 and
            len(re.findall(r'new ToeicQuestion\("R-DX-P7-', extra_diagnostic)) == 4,
            "standard diagnostic must cover P5=6, P6=2, P7=4")
    vocabulary_ids = re.findall(r"new ToeicVocabularyItem\('([^']+)'", preset + "\n" + week_one)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', expansion)
    require(len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', expansion)) == 30,
            "incremental vocabulary must contain exactly 30 curated entries")
    require("V-091" in expansion and "V-120" in expansion and
            "ToeicVocabularyExpansion.idsForDay(day)" in preset,
            "business word expansion must reach the selected daily vocabulary plan")
    require("exampleSentence:string" in models and "item.exampleSentence" in validator,
            "new TOEIC business words must carry reviewed examples")
    sentence_ids = re.findall(r"new ToeicSentenceDrill\('([^']+)'", week_one)
    sentence_ids += re.findall(r'new ToeicSentenceDrill\("([^"]+)"', week_two)
    sentence_ids += re.findall(r'new ToeicSentenceDrill\("([^"]+)"', week_three)
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

    day15_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-P5-SPRINT-[^"]+)"', week_three)
    day16_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-P6-SPRINT-[^"]+)"', week_three)
    day17_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-P7-TIMED-[^"]+)"', week_three)
    require(len(day15_ids) == 30, f"Day 15 Part 5 sprint must contain 30 questions, found {len(day15_ids)}")
    require(len(day16_ids) == 16, f"Day 16 Part 6 sprint must contain 16 questions, found {len(day16_ids)}")
    require(len(day17_ids) == 18, f"Day 17 Part 7 timed set must contain 18 questions, found {len(day17_ids)}")

    mock_two_part5_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-M2-P5-[^"]+)"', week_three)
    mock_two_part6_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-M2-P6-[^"]+)"', week_three)
    mock_two_part7_ids = re.findall(r'ToeicWeekThreeContent\.q\("(R-M2-P7-[^"]+)"', week_three)
    require(len(mock_two_part5_ids) == 30, f"Day 19 Part 5 must contain 30 questions, found {len(mock_two_part5_ids)}")
    require(len(mock_two_part6_ids) == 16, f"Day 19 Part 6 must contain 16 questions, found {len(mock_two_part6_ids)}")
    require(len(mock_two_part7_ids) == 54, f"Day 19 Part 7 must contain 54 questions, found {len(mock_two_part7_ids)}")
    require("new ToeicStudyDay(19" in week_three and "ToeicWeekThreeContent.mockQuestionIds()" in week_three,
            "Day 19 must map to the independent second mock question set")
    require("new ToeicStudyDay(18" in week_three and "new ToeicStudyDay(20" in week_three,
            "Day 18 and Day 20 dynamic review plans must exist")
    require("new ToeicStudyDay(21" in week_three and "ToeicWeekThreeContent.finalCheckQuestionIds()" in week_three,
            "Day 21 final verification plan must exist")

    mock_two_part7_positions = [
        int(value) for value in re.findall(
            r'ToeicWeekThreeContent\.q\("R-M2-P7-[^"]+".*?\],([0-3]),',
            week_three,
        )
    ]
    require(len(mock_two_part7_positions) == 54,
            "Day 19 Part 7 answer positions could not be validated")
    for position in range(4):
        require(mock_two_part7_positions.count(position) >= 10,
                f"Day 19 Part 7 answer position {position} is overly sparse")


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
        "isWeaknessDay(day:number)",
        "isHighErrorReviewDay(day:number)",
        "questionsThroughDay(maxDay:number)",
        "questionsRequiringTranslation():ToeicQuestion[]",
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
    require("PresetToeicContent.isWeaknessDay(studyDay)" in training and
            "weaknessDayQuestions(snapshot,18)" in training,
            "Day 18 must use a dynamic weakness queue")
    require("PresetToeicContent.isHighErrorReviewDay(studyDay)" in training and
            "highErrorReviewQuestions(snapshot,20)" in training,
            "Day 20 must use a high-error review queue")
    require("history.wrongCount<2" in training and
            "histories.sort" in training,
            "Day 20 must prioritize cumulative repeated errors")
    require("recoveryLimit=Math.min(4,limit)" in training,
            "daily queue must cap remediation so planned content still fits")
    require("containsQuestionId(selected,q.id)" in training and
            "selected.indexOf(q)" not in training,
            "daily queue must deduplicate by stable question id, not object identity")

    progress = read("entry/src/main/ets/toeic/data/ToeicProgressStore.ets")
    require("this.snapshot.currentDay=2" in progress,
            "diagnostic must count as Day 1 and advance to Day 2")
    require("MAX_AVAILABLE_STUDY_DAY:number=21" in progress,
            "progress must support the implemented Day 1-21 boundary")
    require("advanceProgress:boolean=true" in progress and
            "if (advanceProgress)" in progress,
            "review or preview sessions must be recordable without advancing currentDay")
    for token in [
        "attemptCount(questionId:string)", "wrongCount(questionId:string)",
        "history.attemptCount++", "if (!attempt.correct) history.wrongCount++",
        "Array.isArray(parsed.questionHistories)", "new ToeicQuestionHistory",
        "restored.schemaVersion=7",
    ]:
        require(token in progress, f"question history persistence missing: {token}")

    view_model = read("entry/src/main/ets/toeic/ui/ToeicCoachViewModel.ets")
    require("questionTranslation(questionId:string)" in view_model and
            "ToeicQuestionTranslationCatalog.find(questionId)" in view_model,
            "TOEIC view model must expose question translations by stable question id")
    require("validateQuestionTranslations" in view_model and
            "PresetToeicContent.questionsRequiringTranslation()" in view_model,
            "TOEIC contentErrors must include question translation validation")

    ui = read("entry/src/main/ets/toeic/ui/ToeicHomePage.ets")
    # Compile regression: FlexSpaceOptions requires LengthMetrics, not raw numbers.
    require("import { LengthMetrics } from '@kit.ArkUI';" in ui and
            "space:{main:LengthMetrics.vp(6),cross:LengthMetrics.vp(6)}" in ui and
            re.search(r"space\s*:\s*\{\s*main\s*:\s*\d+\s*,\s*cross\s*:\s*\d+\s*\}", ui) is None,
            "TOEIC Flex spacing must use LengthMetrics values, not number")
    require("this.getUIContext().showAlertDialog({" in ui and
            "AlertDialog.show(" not in ui,
            "TOEIC mock confirmation must use non-deprecated UIContext alert dialog")
    for token in ["VOCABULARY='VOCABULARY'", "SENTENCE='SENTENCE'", "DaySelector",
                  "DayButton", "VocabularyContent", "SentenceContent", "item.ipa", "Button('发音'",
                  "selectedStudyDay", "selectedDayTitle", "selectStudyDay(day:number)", "effectiveStudyDay()",
                  "this.DayButton(1);", "this.DayButton(7);", "this.DayButton(8);", "this.DayButton(14);",
                  "this.DayButton(15);", "this.DayButton(19);", "this.DayButton(21);",
                  ".onClick(()=>this.selectStudyDay(day))", "dailyQuestionsForDay(day)",
                  "'进入 Day '+this.selectedStudyDay+' 训练'", "currentAttemptCount", "currentWrongCount",
                  "'已做 '+this.currentAttemptCount+' 次'", "'错 '+this.currentWrongCount+' 次'",
                  "'译：'+item.translation", "showQuestionTranslation",
                  "currentTranslationStem", "toggleQuestionTranslation()",
                  "'查看中文翻译'", "'收起中文翻译'"]:
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
    require("private QuestionOption(" not in ui and
            "private QuestionTranslationOption(" not in ui,
            "dynamic option text must not be passed through nested Builder parameters")
    for token in [
        "@State private currentQuestionId:string=''",
        "@State private currentStem:string=''",
        "@State private currentPassage:string=''",
        "@State private currentCorrectIndex:number=-1",
        "@State private currentAttemptCount:number=0",
        "@State private currentWrongCount:number=0",
        "@State private showQuestionTranslation:boolean=false",
        "@State private currentTranslationPassage:string=''",
        "@State private currentTranslationStem:string=''",
        "private loadQuestion(index:number):boolean",
        "this.loadQuestion(0)",
        "this.loadQuestion(this.currentIndex)",
        "this.noteCurrentQuestionTime()",
        "private currentQuestionForAttempt():ToeicQuestion|null",
        "private sessionAttempt(questionId:string):ToeicQuestionAttempt|null",
        "question.id===this.currentQuestionId",
    ]:
        require(token in ui, f"reactive question snapshot missing: {token}")
    require("this.currentAttemptCount=this.viewModel.attemptCount(question.id)" in ui and
            "this.currentWrongCount=this.viewModel.wrongCount(question.id)" in ui,
            "question history badges must load from persisted history")
    require("this.currentAttemptCount++" in ui and
            "if (!this.isMockSession() && !attempt.correct) this.currentWrongCount++" in ui,
            "question history badges must update immediately after answering")
    for token in [
        "private previousQuestion():void",
        "Button('上一题'",
        ".enabled(this.currentIndex>0)",
        ".onClick(()=>this.previousQuestion())",
        ".enabled(this.isMockSession() || this.answerLocked)",
        ".onClick(()=>this.nextQuestion())",
        "attempt===null?-1:attempt.selectedIndex",
        "this.answerCorrect=attempt===null?false:attempt.correct",
        "this.answerLocked=attempt!==null",
        "let existing=this.sessionAttempt(this.currentQuestionId)",
    ]:
        require(token in ui, f"question navigation state restoration missing: {token}")
    require("(!this.answerLocked && !this.isMockSession())" in ui,
            "daily practice must not skip unanswered questions, while mocks may")
    require("this.attempts.push(attempt)" in ui,
            "session attempts must remain the source of answered-question state")
    require("this.showQuestionTranslation=false;" in ui,
            "question translation must reset to collapsed whenever a question snapshot loads")
    require("if (!this.isMockSession() && this.currentTranslationStem.length>0)" in ui,
            "question translation entry must be hidden from full mock sessions")
    require("if (this.isMockSession() || this.currentTranslationStem.length===0) return;" in ui,
            "translation toggle must refuse mock sessions and missing translations")
    require("this.currentTranslationPassage=translation===null?'':translation.passage" in ui and
            "this.currentTranslationStem=translation===null?'':translation.stem" in ui,
            "question translation must load by current question id into reactive snapshot state")

    question_builder_match = re.search(
        r"(?ms)^\s*@Builder\s*\n\s*private QuestionContent\(\).*?(?=^\s*build\(\))",
        ui,
    )
    require(question_builder_match is not None, "QuestionContent builder could not be identified")
    question_builder = question_builder_match.group(0)
    require("this.questions[" not in question_builder,
            "QuestionContent must not render fields directly from class objects in the questions array")
    for token in [
        "Text(this.currentOptionA)", "Text(this.currentOptionB)",
        "Text(this.currentOptionC)", "Text(this.currentOptionD)",
        "Text(this.currentTranslationOptionA)", "Text(this.currentTranslationOptionB)",
        "Text(this.currentTranslationOptionC)", "Text(this.currentTranslationOptionD)",
    ]:
        require(token in question_builder,
                f"QuestionContent must bind option text directly to reactive state: {token}")
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
    require("return this.activeSessionDay===14 || this.activeSessionDay===19" in ui,
            "Day 14 and Day 19 must share the explicit mock-session boundary")
    require("if (day<1 || day>21) return;" in ui,
            "TOEIC day selection must support Day 1-21")
    for token in [
        "private selectedDayGuidance():string",
        "private trainingButtonLabel():string",
        "Day 18 根据当前错题、慢题和薄弱能力动态组题",
        "Day 20 优先复盘累计错 2 次及以上题目",
        "开始 Day 19 第二次完整模考",
        "开始 Day 21 最终验证",
        "@State private mockResultDay:number=0",
        "this.mockResultDay=this.activeSessionDay",
        "this.mockResultDay===19?'第二次完整 Reading 模考':'第一次完整 Reading 模考'",
    ]:
        require(token in ui, f"week-three UI flow missing: {token}")
    require("完整模考过程中不显示对错与解析" in ui and
            "this.mode=mockSession?ToeicPageMode.MOCK_RESULT:ToeicPageMode.HOME" in ui,
            "mock mode must hide immediate feedback and show a result screen after completion")
    require("this.mockPart5Correct" in ui and "this.mockPart6Correct" in ui and "this.mockPart7Correct" in ui,
            "mock result must expose Part 5/6/7 breakdown")
    require("Button('A. '+this.currentOptionA" not in ui and
            "Button('B. '+this.currentOptionB" not in ui and
            "Button('C. '+this.currentOptionC" not in ui and
            "Button('D. '+this.currentOptionD" not in ui,
            "TOEIC answer options must not regress to single-label Button rendering")
    require(question_builder.count("Button({type:ButtonType.Normal})") >= 4 and
            ".constraintSize({minHeight:50})" in question_builder and
            ".padding({left:14,right:14,top:12,bottom:12})" in question_builder and
            ".textAlign(TextAlign.Start)" in question_builder,
            "TOEIC answer options must keep custom multiline Button content and touch-safe layout")
    require(".maxLines(" not in question_builder and ".textOverflow(" not in question_builder,
            "TOEIC answer text must not be truncated by maxLines or ellipsis")


    for token in [
        "@State private progressCurrentDay:number=1",
        "@State private progressDiagnosticCompleted:boolean=false",
        "@State private progressWeakSkill:string=''",
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

    # Persistent exam clock and draft/resume cannot be replaced with a label-only timer.
    model = read("entry/src/main/ets/toeic/domain/ToeicModels.ets")
    for token in ["class ToeicSessionDraft", "class ToeicMockReport", "class ToeicQuestionTime",
                  "activeDraft:ToeicSessionDraft|null", "mockReports:ToeicMockReport[]"]:
        require(token in model, f"missing persistent TOEIC exam model: {token}")
    progress = read("entry/src/main/ets/toeic/data/ToeicProgressStore.ets")
    for token in ["async saveDraft(", "async discardDraft(", "async recordSession(",
                  "this.snapshot.activeDraft=null", "this.snapshot.mockReports.push(mockReport)",
                  "private pendingSave:Promise<void>"]:
        require(token in progress, f"draft or report persistence invariant missing: {token}")
    for token in ["this.sessionStartedAtMs+75*60*1000", "this.mockCountdownSeconds",
                  "this.mockExpired()", "setInterval(()=>this.updateMockClock(),1000)",
                  "this.stopMockClock()", "this.resumeDraft()", "this.persistDraft()",
                  "this.viewModel.completeSession(", "this.confirmMockSubmission()",
                  "this.questions.length-this.attempts.length",
                  "this.mockResultUnanswered", "this.mockReports.length>0"]:
        require(token in ui, f"timed mock / resume / results invariant missing: {token}")
    require("topWeakSkills(snapshot:ToeicLearningSnapshot,limit:number=3):ToeicSkill[]" in training
            and "let ranked=this.topWeakSkills(snapshot,3)" in training,
            "adaptive training must rank multiple skills from cumulative proficiency")
    require("if (weakest.penalty>0)" in training and "summary.hasWeakSkill=true" in training,
            "weak skill must not be fabricated for a perfect fast session")
    for token in ["markedQuestionIds:string[]", "this.markedQuestionIds=markedQuestionIds"]:
        require(token in model, f"exam bookmark field missing: {token}")
    require("Array.isArray(raw.markedQuestionIds)" in progress,
            "exam bookmark ids must be restored after relaunch")
    for token in ["private toggleQuestionMark():void", "private jumpToQuestion(index:number):void",
                  "this.noteCurrentQuestionTime()", "this.persistDraft()",
                  "Flex({wrap:FlexWrap.Wrap", "this.isQuestionMarked(question.id)",
                  "this.markedQuestionIds=draft.markedQuestionIds.slice()"]:
        require(token in ui, f"exam bookmark or question navigation missing: {token}")
    for token in ["this.toggleWordReveal(item.id)", "this.toggleSentenceReveal(item.id)",
                  "this.revealedWordIds.indexOf(item.id)>=0",
                  "this.revealedSentenceIds.indexOf(item.id)>=0",
                  "this.recordWordRecall(item,true)", "this.recordWordRecall(item,false)"]:
        require(token in ui, f"active recall UI missing: {token}")
    require("this.questions.length===0 || this.sessionStartedAtMs===0" in ui,
            "subsequent submission callbacks must not double commit a closed session")

    for token in ["class ToeicVocabularyRecall", "vocabularyRecalls:ToeicVocabularyRecall[]"]:
        require(token in model, f"spaced-repetition model missing: {token}")
    for token in ["async recordVocabularyRecall(", "vocabularyDueIds(", "let intervals:number[]=[0,1,3,7,14]",
                  "Array.isArray(parsed.vocabularyRecalls)"]:
        require(token in progress, f"spaced-repetition persistence missing: {token}")
    require("vocabularyForDay(day:number)" in view_model and
            "ToeicProgressStore.instance.vocabularyDueIds()" in view_model,
            "due vocabulary must enter the selected-day study flow")

    group_service = read("entry/src/main/ets/toeic/application/ToeicReadingGroupService.ets")
    quiz_service = read("entry/src/main/ets/toeic/application/ToeicVocabularyQuizService.ets")
    for token in ["class ToeicDayTaskProgress", "class ToeicSessionReport",
                  "dayTasks:ToeicDayTaskProgress[]", "sessionReports:ToeicSessionReport[]",
                  "class ToeicReadingGroup", "class ToeicVocabularyQuizQuestion"]:
        require(token in model, f"second-stage TOEIC model missing: {token}")
    for token in ["private advanceDayIfReady(day:number)", "private writableDayTasks(day:number)",
                  "async completeDayTask(", "this.advanceDayIfReady(studyDay)",
                  "new ToeicSessionReport(studyDay,Date.now())",
                  "Array.isArray(parsed.dayTasks)", "Array.isArray(parsed.sessionReports)",
                  "Array.isArray(parsed.skillStats)", "new ToeicSkillStat(attempt.skill)"]:
        require(token in progress, f"day task completion or session analytics missing: {token}")
    for token in ["ToeicReadingGroupService.groupAt(this.questions,index)",
                  "this.currentPassageBlocks=readingGroup.passageBlocks",
                  "this.currentGroupCount=readingGroup.questionIds.length",
                  "this.currentGroupPosition=readingGroup.questionIds.indexOf(question.id)+1",
                  "this.DaySelector();", "this.showFullPlan",
                  "this.completedTasksCount()", "this.finishDayTask('sentence')",
                  "this.finishDayTask('vocabulary')",
                  "this.quizOptionA", "this.quizOptionB", "this.quizOptionC", "this.quizOptionD",
                  "ToeicVocabularyQuizMode.MEANING", "ToeicVocabularyQuizMode.COLLOCATION",
                  "ToeicVocabularyQuizMode.PARAPHRASE",
                  "this.quizSelectedIndex>=0"]:
        require(token in ui, f"new TOEIC page capability missing: {token}")
    require("passageBlocks(passage:string):string[]" in group_service and
            "questions[first-1].passage===current.passage" in group_service and
            "questions[last+1].passage===current.passage" in group_service,
            "shared reading passage grouping must preserve article identity")
    require("if (candidate.id===item.id || candidate.scenario===item.scenario) continue;" in quiz_service
            and "distractors.length!==3" in quiz_service
            and "answerFor(item:ToeicVocabularyItem,mode:ToeicVocabularyQuizMode)" in quiz_service,
            "TOEIC vocabulary retrieval quiz must generate unique four-way options")

    shell = read("entry/src/main/ets/pages/AppShell.ets")
    require("TOEIC = 'TOEIC'" in shell, "parent primary TOEIC route is missing")
    require("ToeicHomePage" in shell, "TOEIC home is not connected to AppShell")
    require("@state private toeic" not in shell.lower(), "AppShell must not own TOEIC business state")

    ability = read("entry/src/main/ets/entryability/EntryAbility.ets")
    require("ToeicModuleBootstrap.initialize" in ability, "TOEIC progress bootstrap is missing")

    require("ToeicStandardDiagnosticContent.questions()" in preset and
            "standardDiagnosticQuestions():ToeicQuestion[]" in preset,
            "independent standard-level diagnostic must be reachable from PresetToeicContent")
    require("this.startStandardDiagnostic()" in ui and
            "this.activeSessionAdvancesProgress=false" in ui,
            "supplemental diagnostic must not advance the 21-day plan")

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
        f"mock1=100(30/16/54), mock2=100(30/16/54), pronunciations={pronunciation_entry_count}"
    )


if __name__ == "__main__":
    main()
