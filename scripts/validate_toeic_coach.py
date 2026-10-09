from pathlib import Path
import re
from validate_toeic_editorial_content import validate as validate_editorial_candidates
from export_toeic_review_pack import export_review_pack
from tempfile import TemporaryDirectory
from test_toeic_review_integrity import run_tests as test_review_integrity
from test_toeic_editorial_handoff import run_tests as test_editorial_handoff
from test_toeic_ai_editorial_release import run_tests as test_ai_release
from test_toeic_remaining_editorial import run_tests as test_remaining_editorial
from validate_toeic_question_quality import validate as validate_question_quality
from validate_toeic_answer_display import verify as verify_answer_display
from validate_toeic_mock_format_v2 import validate as validate_mock_day14_v2
from validate_toeic_mock_day19_format_v2 import validate as validate_mock_day19_v2
from validate_toeic_translation_coverage import main as validate_translation_coverage
from validate_toeic_semantic_issue478 import validate as validate_semantic_issue478
from validate_toeic_evidence_provenance import validate as validate_evidence_provenance
from validate_toeic_part7_semantic_first_pass import validate as validate_part7_semantic_first_pass
from validate_toeic_shared_part7_first_pass import validate as validate_shared_part7_first_pass
from validate_toeic_inline_verbatim_first_pass import validate as validate_inline_verbatim_first_pass
from validate_toeic_v2_mock_semantics_issue478 import validate as validate_v2_mock_semantics
from validate_toeic_mock_p5p6_unique_issue478 import validate as validate_mock_p5p6_unique
from validate_toeic_active_mock_p5p6_issue478 import validate as validate_active_mock_p5p6

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
    validate_question_quality()
    validate_semantic_issue478()
    validate_evidence_provenance()
    validate_part7_semantic_first_pass()
    validate_shared_part7_first_pass()
    validate_inline_verbatim_first_pass()
    validate_v2_mock_semantics()
    validate_mock_p5p6_unique()
    validate_active_mock_p5p6()
    verify_answer_display()
    validate_mock_day14_v2()
    validate_mock_day19_v2()
    validate_translation_coverage()
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
            "Chinese translation is required for assigned non-mock training" in validator and
            "translated option count must match question options" in validator,
            "question translation content gate is missing")

    preset = read("entry/src/main/ets/toeic/content/PresetToeicContent.ets")
    week_one = read("entry/src/main/ets/toeic/content/ToeicWeekOneContent.ets")
    week_two = read("entry/src/main/ets/toeic/content/ToeicWeekTwoContent.ets")
    week_three = read("entry/src/main/ets/toeic/content/ToeicWeekThreeContent.ets")
    expansion = read("entry/src/main/ets/toeic/content/ToeicVocabularyExpansion.ets")
    batch_two = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchTwo.ets")
    batch_three = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchThree.ets")
    batch_four = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchFour.ets")
    batch_five = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchFive.ets")
    batch_six = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchSix.ets")
    batch_seven = read("entry/src/main/ets/toeic/content/ToeicVocabularyBatchSeven.ets")
    extra_reading = read("entry/src/main/ets/toeic/content/ToeicExtraReadingContent.ets")
    extra_reading_second = read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchTwo.ets")
    extra_reading_third = read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchThree.ets")
    extra_reading_fourth = read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchFour.ets")
    extra_reading_fifth = read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchFive.ets")
    extra_reading_sixth = read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchSix.ets")
    extra_diagnostic = read("entry/src/main/ets/toeic/content/ToeicStandardDiagnosticContent.ets")
    week_two_question_count = week_two.count("ToeicWeekTwoContent.q(")
    week_three_question_count = week_three.count("ToeicWeekThreeContent.q(")
    question_count = (preset.count("new ToeicQuestion(") + week_one.count("new ToeicQuestion(") +
                      week_two_question_count + week_three_question_count +
                      extra_diagnostic.count("new ToeicQuestion(") +
                      extra_reading.count("new ToeicQuestion(") +
                      extra_reading_second.count("new ToeicQuestion(") +
                      extra_reading_third.count("new ToeicQuestion(") +
                      extra_reading_fourth.count("new ToeicQuestion(") +
                      extra_reading_fifth.count("new ToeicQuestion(") +
                      extra_reading_sixth.count("new ToeicQuestion("))
    vocabulary_count = (preset.count("new ToeicVocabularyItem(") +
                        week_one.count("new ToeicVocabularyItem(") +
                        expansion.count("new ToeicVocabularyItem(") +
                         batch_two.count("new ToeicVocabularyItem(") +
                         batch_three.count("new ToeicVocabularyItem(") +
                         batch_four.count("new ToeicVocabularyItem(") +
                         batch_five.count("new ToeicVocabularyItem(") +
                         batch_six.count("new ToeicVocabularyItem(") +
                         batch_seven.count("new ToeicVocabularyItem("))
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
    translation_week_three = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationWeekThreeCatalog.ets")
    translation_day17 = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationDay17Catalog.ets")
    translation_day18_20 = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationDay18And20Catalog.ets")
    translation_extra = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationSupplementaryCatalog.ets")
    translation_catalog = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationCatalog.ets")
    translation_ids = re.findall(r"new ToeicQuestionTranslation\('([^']+)'", translation_week_one + "\n" + translation_week_two)
    translation_ids += re.findall(r'new ToeicQuestionTranslation\("([^"]+)"', translation_week_two + "\n" + translation_extra)
    translation_ids += re.findall(r"new ToeicQuestionTranslation\('([^']+)'", translation_week_three)
    translation_ids += re.findall(r'new ToeicQuestionTranslation\("([^"]+)"', translation_day17 + "\n" + translation_day18_20)
    require(len(translation_ids) == 221,
            f"Day1-21 non-mock drills must have 221 unique translations, found {len(translation_ids)}")
    require(len(re.findall(r'new ToeicQuestionTranslation\("R-P7-TIMED-', translation_day17)) == 18 and
            len(re.findall(r'new ToeicQuestionTranslation\("R-P7-(?:ONBOARD|RETAIL|SUPPORT|LEASE)-', translation_day17)) == 20 and
            len(re.findall(r'new ToeicQuestionTranslation\("R-P7-(?:TRAINING|MIGRATION|LICENSE|PERDIEM|CATERING)-', translation_day18_20)) == 25,
            "Day17-20 translations must cover 18 timed plus all 45 supplementary questions")
    require(len(translation_ids) == len(set(translation_ids)),
            "TOEIC question translation ids must be unique")
    require(not any(question_id.startswith("R-M1-") or question_id.startswith("R-M2-") for question_id in translation_ids),
            "full mock questions must not have Chinese translations")
    require("ToeicQuestionTranslationWeekOneCatalog.items()" in translation_catalog and
            "ToeicQuestionTranslationWeekTwoCatalog.items()" in translation_catalog and
            "ToeicQuestionTranslationWeekThreeCatalog.items()" in translation_catalog and
            "ToeicQuestionTranslationSupplementaryCatalog.items()" in translation_catalog and
            "ToeicQuestionTranslationDay17Catalog.items()" in translation_catalog and
            "ToeicQuestionTranslationDay18And20Catalog.items()" in translation_catalog and
            "for (let day=1; day<=21; day++)" in preset,
            "translation catalog must cover every Day1-21 non-mock assigned question")

    diagnostic_match = re.search(
        r"new ToeicStudyDay\(1,.*?\[\],\[\],\[(.*?)\]\),",
        week_one, flags=re.S,
    )
    require(diagnostic_match is not None, "Day 1 integrated diagnostic question list is missing")
    diagnostic_ids = re.findall(r"'(R-[^']+)'", diagnostic_match.group(1))
    require(len(diagnostic_ids) == 20 and len(set(diagnostic_ids)) == 20,
            f"Day 1 must contain 20 distinct questions, found {len(diagnostic_ids)}")
    require((sum('P5' in item for item in diagnostic_ids),
             sum('P6' in item for item in diagnostic_ids),
             sum('P7' in item for item in diagnostic_ids)) == (10,4,6),
            "Day 1 combined diagnostic must cover P5=10 / P6=4 / P7=6")
    require(diagnostic_ids[-2:] == ['R-DX-P7-03','R-DX-P7-04'] and
            diagnostic_ids[12:14] == ['R-DX-P6-01','R-DX-P6-02'],
            "Day 1 must retain intact Part 6 and cross-document passage pairs")

    question_ids = re.findall(r"new ToeicQuestion\('([^']+)'", preset + "\n" + week_one)
    question_ids += re.findall(r'ToeicWeekTwoContent\.q\("([^"]+)"', week_two)
    question_ids += re.findall(r'ToeicWeekThreeContent\.q\("([^"]+)"', week_three)
    question_ids += re.findall(r'new ToeicQuestion\("(R-DX-[^"]+)"', extra_diagnostic)
    extra_ids = re.findall(r'new ToeicQuestion\("(R-P7-[A-Z-]+-[0-9]+)"', extra_reading + "\n" + extra_reading_second + "\n" + extra_reading_third + "\n" + extra_reading_fourth + "\n" + extra_reading_fifth + "\n" + extra_reading_sixth)
    question_ids += extra_ids
    require(len(extra_ids) == 65 and len(set(extra_ids)) == 65,
            "supplemental multi-document reading must contain 65 stable unique questions")
    combined_extra = extra_reading + "\n" + extra_reading_second + "\n" + extra_reading_third + "\n" + extra_reading_fourth + "\n" + extra_reading_fifth + "\n" + extra_reading_sixth
    require(combined_extra.count("new ToeicReadingGroup(") == 13 and
            (combined_extra.count("ToeicReviewStatus.REVIEWED") +
             combined_extra.count("ToeicReviewStatus.PUBLISHED")) == 65,
            "all supplementary passage questions must retain a valid review state")
    require("ToeicExtraReadingContent.questions()" in preset and
            "ToeicExtraReadingContent.groups()" in preset and
            "ToeicExtraReadingBatchTwo.questions()" in preset and
            "ToeicExtraReadingBatchTwo.groups()" in preset and
            "ToeicExtraReadingBatchThree.questions()" in preset and
            "ToeicExtraReadingBatchThree.groups()" in preset and
            "ToeicExtraReadingBatchFour.questions()" in preset and
            "ToeicExtraReadingBatchFour.groups()" in preset and
            "ToeicExtraReadingBatchFive.questions()" in preset and
            "ToeicExtraReadingBatchFive.groups()" in preset and
            "ToeicExtraReadingBatchSix.questions()" in preset and
            "ToeicExtraReadingBatchSix.groups()" in preset,
            "supplemental content must be registered for review validation")
    require(len(re.findall(r'new ToeicQuestion\("(R-DX-[^"]+)"', extra_diagnostic)) == 12,
            "legacy diagnostic bank must retain all twelve IDs for saved drafts")
    require(len(re.findall(r'new ToeicQuestion\("R-DX-P5-', extra_diagnostic)) == 6 and
            len(re.findall(r'new ToeicQuestion\("R-DX-P6-', extra_diagnostic)) == 2 and
            len(re.findall(r'new ToeicQuestion\("R-DX-P7-', extra_diagnostic)) == 4,
            "preserved diagnostic question bank must retain its original P5/P6/P7 assets")
    vocabulary_ids = re.findall(r"new ToeicVocabularyItem\('([^']+)'", preset + "\n" + week_one)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', expansion)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_two)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_three)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_four)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_five)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_six)
    vocabulary_ids += re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_seven)
    require(len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_two)) == 30 and
            len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_three)) == 30 and
            len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_four)) == 30 and
            len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_five)) == 30 and
            len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_six)) == 30 and
            len(re.findall(r'new ToeicVocabularyItem\("(V-[0-9]+)"', batch_seven)) == 30,
            "both staged vocabulary batches must each contain 30 business word entries")
    require("ToeicVocabularyBatchTwo.idsForDay(day)" in preset and
            "ToeicVocabularyBatchTwo.items()" in preset and
            "ToeicVocabularyBatchThree.idsForDay(day)" in preset and
            "ToeicVocabularyBatchThree.items()" in preset and
            "ToeicVocabularyBatchFour.idsForDay(day)" in preset and
            "ToeicVocabularyBatchFour.items()" in preset and
            "ToeicVocabularyBatchFive.idsForDay(day)" in preset and
            "ToeicVocabularyBatchFive.items()" in preset and
            "ToeicVocabularyBatchSix.items()" in preset and
            "ToeicVocabularyBatchSix.idsForDay(day)" in preset and
            "ToeicVocabularyBatchSeven.items()" in preset and
            "ToeicVocabularyBatchSeven.idsForDay(day)" in preset,
            "second vocabulary batch must be scheduled and surfaced from the catalog")
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
        "restored.schemaVersion=10",
    ]:
        require(token in progress, f"question history persistence missing: {token}")

    # Manual important-word marks were removed in v9. Only automatic forgotten
    # words remain persisted; legacy v8 progress and reviews must not be reset.
    models = read("entry/src/main/ets/toeic/domain/ToeicModels.ets")
    require("schemaVersion:number=10" in models and
            "unrememberedVocabularyIds:string[]=[]" in models and
            "importantVocabularyIds" not in models,
            "v9 snapshot must retain only the automatic weak-word flag")
    for token in [
        "isUnrememberedVocabulary(vocabularyId:string)",
        "restored.unrememberedVocabularyIds.push(value as string)",
        "if (!remembered && weakIndex<0) weakIds.push(vocabularyId)",
        "if (remembered && weakIndex>=0) weakIds.splice(weakIndex,1)",
        "review.streak=remembered?Math.min(4,review.streak+1):0",
        "review.nextDueAtMs=nowMs+delayMs",
        "await this.save()",
    ]:
        require(token in progress, f"TOEIC forgotten-word priority / spaced repetition missing: {token}")
    require("setVocabularyImportant(" not in progress and
            "isImportantVocabulary(" not in progress and
            "this.snapshot.importantVocabularyIds" not in progress and
            "restored.importantVocabularyIds" not in progress and
            "Array.isArray(parsed.importantVocabularyIds)" not in progress and
            "Legacy v8 manual importantVocabularyIds are deliberately ignored." in progress,
            "manual mark mutations/loading must be removed while old v8 flags are safely ignored")
    view_model = read("entry/src/main/ets/toeic/ui/ToeicCoachViewModel.ets")
    require("let weak:ToeicVocabularyItem[]=[]" in view_model and
            "let regular:ToeicVocabularyItem[]=[]" in view_model and
            "return weak.concat(regular)" in view_model and
            "let important:ToeicVocabularyItem[]=[]" not in view_model and
            "isImportantVocabulary(" not in view_model and
            "setVocabularyImportant(" not in view_model and
            "let due=ToeicProgressStore.instance.vocabularyDueIds()" in view_model and
            "let result:ToeicVocabularyItem[]=planned.slice()" in view_model,
            "TOEIC vocabulary must prioritize forgotten words without altering planned/due queues")
    require("questionTranslation(questionId:string)" in view_model and
            "ToeicQuestionTranslationCatalog.find(questionId)" in view_model,
            "TOEIC view model must expose question translations by stable question id")
    require("validateQuestionTranslations" in view_model and
            "PresetToeicContent.questionsRequiringTranslation()" in view_model,
            "TOEIC contentErrors must include question translation validation")

    ui = read("entry/src/main/ets/toeic/ui/ToeicHomePage.ets")
    require("标记重点" not in ui and
            "取消重点" not in ui and
            "toggleVocabularyImportant" not in ui and
            "importantVocabularyIds" not in ui and
            "this.unrememberedVocabularyIds=snapshot.unrememberedVocabularyIds.slice()" in ui and
            "this.vocabularyItems=this.viewModel.vocabularyForDay(this.effectiveStudyDay())" in ui and
            "this.unrememberedVocabularyIds=this.viewModel.snapshot().unrememberedVocabularyIds.slice()" in ui and
            "this.VocabularyContent(this.vocabularyItems);" in ui and
            "this.refreshVocabularyItems();" in ui and
            "this.loadProgressSnapshot()" in ui[ui.index("  private async recordWordRecall("):
                                                  ui.index("  private async pronounce(")],
            "vocabulary UI must use an observable display list and preserve automatic weak-word priority")
    # TOEIC page chrome must stay outside the independent scrolling content pane.
    require("private FixedHeader()" in ui and "private FixedFooter()" in ui and
            "private hasFixedFooter():boolean" in ui,
            "TOEIC must centralize fixed page chrome")
    root = ui[ui.index("  build() {"):]
    require("this.FixedHeader();" in root and "this.FixedFooter();" in root and
            "if (this.hasFixedFooter())" in root,
            "TOEIC root must place fixed header/footer around the content pane")
    for name in ["HomeContent", "VocabularyContent", "VocabularyQuizContent",
                 "VocabularyResultContent", "PracticeResultContent",
                 "SentenceContent", "MockResultContent", "QuestionContent"]:
        section = re.search(
            rf"(?ms)^  @Builder\n  private {name}\([^\n]*\) \{{\n(.*?)(?=^  @Builder|^  build\(\))",
            ui,
        )
        require(section is not None and "Scroll() {" in section.group(1) and
                "DeepPageHeader({" not in section.group(1) and
                ".layoutWeight(1).scrollBar(BarState.Off)" in section.group(1),
                f"TOEIC {name} must be the scroll-only middle pane")
    require(ui.count(".layoutWeight(1).scrollBar(BarState.Off)") == 8,
            "TOEIC all eight content panes including deferred result screens must fill available space")
    footer = ui[ui.index("  private FixedFooter()"):ui.index("  @Builder\n  private HomeContent()")]
    for token in ["Button('上一题'", "this.nextQuestion()", "this.leavePracticeResult()",
                  "this.finishDayTask('vocabulary')", "this.finishDayTask('sentence')",
                  "this.startTraining()", "this.leaveMockResult()"]:
        require(token in footer, f"TOEIC fixed footer action missing: {token}")
    # Action buttons share typography, height, radius and touch dimensions.
    # Day chips, question navigation chips and multiline answer tiles are distinct control roles.
    action_count = 0
    quiz_choice_count = 0
    for button_match in re.finditer(r"(?m)^\s*Button\(", ui):
        start = button_match.start()
        end = ui.find(".onClick(", start)
        require(end >= 0, "TOEIC button must have an onClick handler")
        body = ui[start:end]
        first_line = body.lstrip().splitlines()[0]
        if first_line.startswith("Button('Day '"):
            require(".height(40)" in body and "AppTheme.CONTROL_RADIUS" in body,
                    "TOEIC day selection chips must preserve the compact navigation style")
            continue
        if first_line.startswith("Button((this.isQuestionMarked(question.id)"):
            require(".width(48).height(42)" in body and "AppTheme.CONTROL_RADIUS" in body,
                    "TOEIC mock navigator chips must preserve their accessible size")
            continue
        if first_line.startswith("Button({type:ButtonType.Normal}) {"):
            quiz_choice_count += 1
            require(".constraintSize({minHeight:50})" in body and
                    ".borderRadius(AppTheme.CONTROL_RADIUS)" in body and
                    ".border({width:1,color:" in body,
                    "TOEIC answer options must have the shared tile border and radius")
            continue
        action_count += 1
        require(".fontSize(AppTheme.ACTION_TEXT_SIZE)" in body and
                ".borderRadius(AppTheme.CONTROL_RADIUS)" in body and
                (".height(AppTheme.BUTTON_HEIGHT)" in body or
                 ".height(AppTheme.SECONDARY_BUTTON_HEIGHT)" in body),
                f"TOEIC action button inconsistent: {first_line}")
    require(action_count == 26 and quiz_choice_count == 8,
            "TOEIC all 26 action buttons and eight choice tiles must be inspected")
    require("Button('发音',{type:ButtonType.Normal})" in ui and
            ".height(AppTheme.SECONDARY_BUTTON_HEIGHT)" in ui,
            "TOEIC pronunciation must preserve at least the standard secondary touch target")
    # The home page must put the current day's work ahead of optional analysis and drills.
    home_start = ui.index("  private HomeContent()")
    home_end = ui.index("  private VocabularyContent(", home_start)
    home = ui[home_start:home_end]
    require(home.index("this.TodayCard();") < home.index("this.showLearningDetails"),
            "TOEIC home must lead with the selected-day card before optional tools and history")
    require("this.selectStudyDay(this.selectedStudyDay-1)" in home and
            "this.selectStudyDay(this.selectedStudyDay+1)" in home and
            ".enabled(this.selectedStudyDay>1)" in home and
            ".enabled(this.selectedStudyDay<21)" in home and
            "this.DaySelector();" in home,
            "TOEIC home must offer bounded previous/next day and full Day 1-21 selection")
    require("if (this.showLearningDetails)" in home and
            "showPracticeTools" not in ui and
            "更多训练 · 水平诊断" not in home and
            "this.recentReports.length>0" in home and
            "this.mockReports.length>0" in home,
            "TOEIC optional training, learning history and mocks must remain accessible")
    require("Text('训练原则')" not in home and "首批词库 " not in ui,
            "TOEIC home must not restore redundant guidance and inventory chrome")
    require("this.draftLabel.length>0" in home and
            "this.resumeDraft()" in home and
            "this.discardSavedDraft()" in home,
            "TOEIC unfinished session must remain recoverable from the home page")
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
                  "'进入 Day '+this.selectedStudyDay+' 训练'", "practiceReviewItems",
                  "'累计已做 '+item.attemptCount+' 次 · 累计错误 '+item.wrongCount+' 次'",
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
        "@State private practiceReviewItems:ToeicPracticeReviewItem[]=[]",
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
    require("this.currentAttemptCount" not in ui and
            "this.currentWrongCount" not in ui and
            "this.viewModel.attemptCount(question.id),this.viewModel.wrongCount(question.id)" in ui,
            "historical attempt/wrong counts must only be displayed from persisted data after submission")
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
    ]:
        require(token in question_builder, f"QuestionContent must render reactive snapshot field: {token}")
    require("index===this.currentCorrectIndex" not in ui and
            "return this.answerLocked && index===this.selectedIndex?AppTheme.PRIMARY_SOFT:AppTheme.SURFACE;" in ui,
            "question options must not reveal the correct answer during training")
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
        "Day 18 优先复习错题、慢题及薄弱能力",
        "Day 20 优先复盘累计错 2 次及以上题目",
        "开始 Day 19 第二次完整模考",
        "开始 Day 21 最终验证",
        "@State private mockResultDay:number=0",
        "this.mockResultDay=this.activeSessionDay",
        "this.mockResultDay===19?'第二次完整 Reading 模考':'第一次完整 Reading 模考'",
    ]:
        require(token in ui, f"week-three UI flow missing: {token}")
    require("this.mode=mockSession?ToeicPageMode.MOCK_RESULT:ToeicPageMode.PRACTICE_RESULT" in ui and
            "this.preparePracticeResult()" in ui and
            "this.mode===ToeicPageMode.PRACTICE_RESULT" in ui,
            "daily practice must show a complete result page after saving without changing mock result behavior")
    # Every answered choice is captured before moving to the next question.
    # The review is constructed only AFTER the session has been saved.
    choose_block = ui[ui.index("  private chooseAnswer(index:number):void"):ui.index("  private previousQuestion():void")]
    finish_block = ui[ui.index("  private async finishSession():Promise<void>"):
                      ui.index("  private toggleQuestionTranslation():void")]
    result_block = ui[ui.index("  private PracticeResultContent()"):
                      ui.index("  private QuestionContent()")]
    question_view = ui[ui.index("  private QuestionContent()"):ui.index("  build() {")]
    quiz_view = ui[ui.index("  private VocabularyQuizContent()"):ui.index("  private SentenceContent(")]
    require("this.attempts.push(attempt)" in choose_block and
            "this.persistDraft();" in choose_block and
            "this.nextQuestion();" in choose_block and
            choose_block.index("this.persistDraft();") < choose_block.index("this.nextQuestion();"),
            "single choice must persist before automatic next-question navigation")
    require("await this.viewModel.completeSession(" in finish_block and
            finish_block.index("await this.viewModel.completeSession(") <
            finish_block.index("this.preparePracticeResult()") and
            "this.viewModel.attemptCount(question.id)" in finish_block and
            "this.viewModel.wrongCount(question.id)" in finish_block,
            "practice review history must be calculated after the completed session is persisted")
    require("if (this.answerLocked)" not in question_view and
            "this.currentExplanation" not in question_view and
            "this.currentCorrectIndex" not in question_view and
            "已做 '+this.currentAttemptCount" not in question_view,
            "practice must never reveal per-question feedback or in-progress historical totals")
    require("quizSelectedIndex===this.quizAnswerIndex?" not in quiz_view and
            "this.quizExplanation" not in quiz_view and
            "this.mode=ToeicPageMode.VOCABULARY_RESULT" in ui and
            "this.quizAnswers=this.quizAnswers.concat([index]);" in ui and
            "this.loadVocabularyQuiz(this.quizPosition+1)" in ui,
            "vocabulary choice quiz must auto-advance and reveal answers only at completion")
    require("ForEach(this.practiceReviewItems" in result_block and
            "累计已做 '+item.attemptCount+" in result_block and
            "累计错误 '+item.wrongCount+" in result_block and
            "Text('解析：'+item.explanation)" in result_block,
            "final result must show per-question explanations and persisted attempt/wrong totals")
    require("private VocabularyResultContent()" in ui and
            "this.VocabularyResultContent();" in ui and
            "this.PracticeResultContent();" in ui and
            "this.leavePracticeResult()" in ui,
            "both vocabulary and practice sessions must have complete deferred result screens")
    # Published answer options are displayed through a stable permutation only.
    # Canonical selectedIndex stays intact in drafts, reports and scores.
    require("class ToeicMockAnswerRecord" in models and
            "answers:ToeicMockAnswerRecord[]" in models and
            "answers:ToeicMockAnswerRecord[]=[]" in models and
            "new ToeicMockAnswerRecord(" in progress and
            "Array.isArray(report.answers)" in progress and
            "selected< -1 || selected>3" in progress,
            "mock question-level canonical answer records must persist and migrate safely")
    mock_review=ui[ui.index("  private openMockHistoryReport("):
                   ui.index("  private leavePracticeResult()")]
    require("this.viewModel.questionsForIds(ids)" in mock_review and
            "question.version!==answer.questionVersion" in mock_review and
            "this.mockReviewUnavailable++" in mock_review and
            "this.mode=ToeicPageMode.MOCK_RESULT" in mock_review,
            "historical mock review must not regrade a changed published item version")
    require("report.answers.push(new ToeicMockAnswerRecord(" in ui and
            "this.preparePracticeResult();" in ui and
            "this.openMockHistoryReport(report)" in ui and
            "ForEach(this.practiceReviewItems" in ui[ui.index("  private MockResultContent()"):
                                                  ui.index("  private PracticeResultContent()")],
            "fresh and archived mock reports must support post-submission item-by-item review")
    require("questionsForIds(ids:string[]):ToeicQuestion[]" in view_model and
            "return this.questionsForIds(draft.questionIds)" in view_model,
            "question IDs must resolve consistently for drafts and saved report reviews")
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
    for token in ["this.toggleSentenceReveal(item.id)",
                  "this.revealedSentenceIds.indexOf(item.id)>=0",
                  "private async recordWordRecall(item:ToeicVocabularyItem):Promise<void>"]:
        require(token in ui, f"active recall UI missing: {token}")
    vocabulary_section = ui[ui.index("  private VocabularyContent("):
                           ui.index("  private VocabularyQuizContent()")]
    require("revealedWordIds" not in ui and
            "toggleWordReveal" not in ui and
            "查看词义与搭配" not in vocabulary_section and
            "收起词义" not in vocabulary_section and
            "Text(item.meaning)" in vocabulary_section and
            "Text('场景：'+item.scenario)" in vocabulary_section and
            "Text('例句：'+item.exampleSentence)" in vocabulary_section and
            "Text('搭配：'+item.collocations.join(' · '))" in vocabulary_section and
            "Text('同义：'+item.paraphrases.join(' · '))" in vocabulary_section,
            "vocabulary definition, context, example, collocations and paraphrases must be visible without disclosure")
    require("this.unrememberedVocabularyIds.indexOf(item.id)>=0?'记住了':'没记住'" in vocabulary_section and
            vocabulary_section.count("this.recordWordRecall(item)") == 1 and
            "this.updatingVocabularyId===item.id?'保存中…'" in vocabulary_section and
            ".enabled(this.updatingVocabularyId.length===0)" in vocabulary_section and
            "if (this.unrememberedVocabularyIds.indexOf(item.id)>=0)" in vocabulary_section and
            "(this.unrememberedVocabularyIds.indexOf(item.id)>=0?'-weak':'-normal')" in vocabulary_section and
            "unrememberedIds" not in vocabulary_section and
            "ForEach(items,(item:ToeicVocabularyItem)=>" in vocabulary_section,
            "single recall action must bind live @State and rebuild the keyed card on weak status changes")
    recall_handler = ui[ui.index("  private async recordWordRecall("):
                        ui.index("  private toggleSentenceReveal(")]
    require("if (this.updatingVocabularyId.length>0) return" in recall_handler and
            "this.viewModel.snapshot().unrememberedVocabularyIds.indexOf(item.id)>=0" in recall_handler and
            "let saving=this.viewModel.recordVocabularyRecall(item.id,remembered)" in recall_handler and
            "this.refreshVocabularyItems();" in recall_handler and
            "await saving;" in recall_handler and
            recall_handler.index("this.refreshVocabularyItems();") < recall_handler.index("await saving;") and
            "this.loadProgressSnapshot()" in recall_handler and
            "this.updatingVocabularyId=''" in recall_handler,
            "recall must update the visible state immediately, guard double taps and persist the same word status")
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
    for token in ["static validateReadingGroups(", "cross-document question must cite at least two documents",
                  "group question must not duplicate passage", "evidence missing in linked documents"]:
        require(token in validator, f"multi-document editorial gate missing: {token}")
    for token in ["groupId:string", "this.groupId=groupId"]:
        require(token in model, f"explicit group question reference missing: {token}")
    require("this.currentPassage=readingGroup.passageBlocks.join(" in ui and
            "startSupplementaryReading" not in ui and
            "supplementaryReadingQuestionsForDay(day:number)" in preset and
            "supplementaryReadingQuestionsForDay(studyDay)" in training and
            "ToeicExtraReadingContent.groups()" in group_service and
            "ToeicExtraReadingBatchTwo.groups()" in group_service and
            "ToeicExtraReadingBatchThree.groups()" in group_service and
            "ToeicExtraReadingBatchFour.groups()" in group_service and
            "ToeicExtraReadingBatchFive.groups()" in group_service and
            "ToeicExtraReadingBatchSix.groups()" in group_service and
            "for (let group of PresetToeicContent.publishedReadingGroups())" in preset,
            "supplemental shared articles must be accessible only after publication")
    require("PresetToeicContent.publishedReadingGroups()" in view_model and
            "publishedReadingGroups():ToeicReadingGroup[]" in preset and
            "ToeicContentValidator.validateAll(published)" in preset,
            "unpublished candidate errors must not block an existing published question catalog")
    require("let readyGroups=PresetToeicContent.publishedReadingGroups()" in preset and
            "if (q.groupId.length>0)" in preset and
            "if (!groupReady) continue;" in preset and
            "validateReadingGroups(published,readyGroups)" in preset,
            "incomplete P7 shared-passage group must not leak through publishedQuestions")
    require("static vocabularyForReview():ToeicVocabularyItem[]" in preset and
            "item.reviewStatus===ToeicReviewStatus.PUBLISHED" in preset and
            "reviewStatus:ToeicReviewStatus" in model,
            "vocabulary publication must respect explicit review state")
    require("undefined" not in combined_extra,
            "supplemental questions contain an invalid undefined constructor argument")
    require("ToeicReviewStatus" in combined_extra and
            "static publishedReadingGroups()" not in combined_extra,
            "supplemental reading publication must be controlled centrally")
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
    # Supplemental Part 7 questions are now assigned exactly once within the 21-day plan.
    # Only complete five-question published groups can be included, and both mock days stay fixed.
    expected_groups = {
        12: ["P7-EX-VENUE", "P7-EX-DELIVERY"],
        13: ["P7-EX-TRAVEL", "P7-EX-FILTER"],
        17: ["P7-EX-ONBOARD", "P7-EX-RETAIL", "P7-EX-SUPPORT", "P7-EX-LEASE"],
        18: ["P7-EX-TRAINING", "P7-EX-MIGRATION", "P7-EX-LICENSE"],
        20: ["P7-EX-PERDIEM", "P7-EX-CATERING"],
    }
    schedule = re.findall(
        r"if \(day===([0-9]+)\) return \[([^\]]+)\];",
        preset[preset.index("static supplementaryGroupIdsForDay("):preset.index("static supplementaryReadingQuestionsForDay(")],
    )
    actual = {int(day): re.findall(r"'(P7-EX-[A-Z]+)'", ids) for day, ids in schedule}
    require(actual == expected_groups, "Part 7 daily schedule must cover 13 groups on Day 12/13/17/18/20")
    planned_groups = [item for day in actual.values() for item in day]
    require(len(planned_groups) == 13 and len(set(planned_groups)) == 13,
            "Part 7 supplementary group IDs must be scheduled once and only once")
    reading_sources = "".join([
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingContent.ets"),
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchTwo.ets"),
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchThree.ets"),
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchFour.ets"),
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchFive.ets"),
        read("entry/src/main/ets/toeic/content/ToeicExtraReadingBatchSix.ets"),
    ])
    authored_groups = re.findall(r'new ToeicReadingGroup\("([^"]+)"', reading_sources)
    require(set(authored_groups) == set(planned_groups) and len(authored_groups) == 13,
            "Part 7 schedule must cover each authored reading group exactly once")
    require("ordered.length===group.questionIds.length" in preset and
            "for (let questionId of group.questionIds)" in preset and
            "if (group.groupId!==id) continue;" in preset,
            "Part 7 daily sessions must preserve original five-question published group integrity")
    require("supplementaryReadingQuestionsForDay(day)" in preset and
            "if (PresetToeicContent.supplementaryGroupIdsForDay(studyDay).length>0) return planned;" in training,
            "Part 7 daily batches must be contiguous rather than re-sorted by weak skills")
    require("this.weaknessDayQuestions(snapshot,18)" in training and
            "this.highErrorReviewQuestions(snapshot,20)" in training and
            training.count(".concat(PresetToeicContent.supplementaryReadingQuestionsForDay(studyDay))") == 2,
            "Part 7 Day 18/20 must preserve their adaptive review and append complete new groups")
    require("PresetToeicContent.isMockDay(studyDay)) return planned;" in training and
            "if (day===14)" not in preset[preset.index("static supplementaryGroupIdsForDay("):preset.index("static supplementaryReadingQuestionsForDay(")] and
            "if (day===19)" not in preset[preset.index("static supplementaryGroupIdsForDay("):preset.index("static supplementaryReadingQuestionsForDay(")],
            "Part 7 supplemental schedule must not alter two complete mock exams")
    require("ToeicQuestionTranslationSupplementaryCatalog.items()" in read(
        "entry/src/main/ets/toeic/content/ToeicQuestionTranslationCatalog.ets"),
        "Day 12/13 extra Part 7 groups need Chinese translations for learning mode")
    translation_extra = read("entry/src/main/ets/toeic/content/ToeicQuestionTranslationSupplementaryCatalog.ets")
    translated_ids = re.findall(r'new ToeicQuestionTranslation\("([^"]+)"', translation_extra)
    require(len(translated_ids) == 20 and len(set(translated_ids)) == 20,
            "Day 12/13 extra Part 7 groups must have 20 independent translated questions")
    for gid in expected_groups[12] + expected_groups[13]:
        prefix = gid.replace("P7-EX-", "R-P7-") + "-"
        require(sum(item.startswith(prefix) for item in translated_ids) == 5,
                f"Day 12/13 complete reading group needs five translations: {gid}")
    require("Button('Part 7 双篇 / 三篇加练'" not in ui and
            "更多训练 · 水平诊断" not in ui,
            "Standalone Part 7 bonus and global diagnostic entries must remain removed")
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

    validate_editorial_candidates()
    test_review_integrity()
    test_editorial_handoff()
    test_ai_release()
    test_remaining_editorial()
    # Review exports must remain complete as more batches are added.
    with TemporaryDirectory() as temp_dir:
        exported = export_review_pack(Path(temp_dir))
        require(exported == {"vocabulary": 180, "questions": 65, "groups": 13},
                f"editorial export coverage mismatch: {exported}")
        require((Path(temp_dir) / "vocabulary-review.csv").exists() and
                (Path(temp_dir) / "part7-review.md").exists() and
                (Path(temp_dir) / "review-queue.md").exists() and
                (Path(temp_dir) / "manifest.json").exists(),
                "editorial review packet not written")
        import csv
        with (Path(temp_dir) / "vocabulary-review.csv").open(
                "r", newline="", encoding="utf-8-sig") as handle:
            review_rows = list(csv.DictReader(handle))
        require(len(review_rows) == exported["vocabulary"] and
                review_rows[0]["id"] == "V-121" and
                review_rows[-1]["id"] == "V-300",
                "offline vocabulary review export lost items or stable ID ordering")
        review_text = (Path(temp_dir) / "part7-review.md").read_text(encoding="utf-8")
        require(review_text.count("### 题 ") == exported["questions"] and
                review_text.count("## P7-EX-") == exported["groups"],
                "offline reading review pack omitted groups or questions")
        queue = (Path(temp_dir) / "review-queue.md").read_text(encoding="utf-8")
        require(queue.count("| V-") == exported["vocabulary"] // 30 and
                queue.count("| P7-EX-") == exported["groups"],
                "editorial review queue omitted vocabulary batches or reading groups")


    # A single 20-item Day 1 baseline replaces the two former separate entry points.
    # Preserve all original question IDs and the draft-based resume path.
    day_one = ui[ui.index("  private TodayCard()"):ui.index("  private DayButton(")]
    day_one_entry = ui[ui.index("  private startTraining()"):ui.index("  private openVocabulary()")]
    view_model = read("entry/src/main/ets/toeic/ui/ToeicCoachViewModel.ets")
    training_service = read("entry/src/main/ets/toeic/application/ToeicTrainingService.ets")
    require("ToeicStandardDiagnosticContent.questions()" in preset and
            "return PresetToeicContent.questionsForDay(1);" in preset,
            "the single Day 1 diagnostic must reuse the published question bank and plan ordering")
    require("static standardDiagnosticQuestions()" not in preset and
            "standardDiagnosticQuestions()" not in ui and
            "standardDiagnosticQuestions()" not in view_model and
            "standardDiagnosticQuestions()" not in training_service and
            "startStandardDiagnostic()" not in ui and
            "标准水平复测" not in day_one,
            "Day 1 must not expose a separate standard diagnosis or retest")
    require("this.viewModel.diagnosticQuestions()" in day_one_entry and
            "this.activeSessionAdvancesProgress=!this.progressDiagnosticCompleted" in day_one_entry and
            "this.startSession(ToeicPageMode.DIAGNOSTIC" in day_one_entry,
            "Day 1 must enter one 20-question diagnostic and advance only on first completion")
    require("20 题综合诊断" in day_one and
            "this.selectedStudyDay===1?'/1':'/3'" in day_one and
            "if (this.selectedStudyDay===1) return this.progressDiagnosticCompleted?1:0;" in ui,
            "Day 1 must display the single completion milestone and updated question count")
    require("questionsForDraft(draft:ToeicSessionDraft)" in view_model and
            "return this.questionsForIds(draft.questionIds)" in view_model and
            "for (let id of ids)" in view_model and
            "this.questions=restored" in ui and
            "this.activeSessionAdvancesProgress=draft.advancesProgress" in ui,
            "legacy saved 12-question Day 1 drafts must resume with their original stable IDs")
    require("this.TodayCard();" in home and
            "startStandardDiagnostic()" not in home,
            "the standard retest must not remain in the home layout")

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
