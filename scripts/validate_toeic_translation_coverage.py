#!/usr/bin/env python3
"""Cross-day TOEIC translation integrity checks.

Check every existing translated choice aligns to a published, canonical-English
question; enforce Day17–21 training coverage without exposing translations
during mocks. This deterministic check is NOT an independent semantic review.
"""
from __future__ import annotations
import ast
from collections import Counter
from pathlib import Path
from validate_toeic_question_quality import collect, fields, literals_after

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/"entry/src/main/ets/toeic/content"
FILES=(
    "ToeicQuestionTranslationWeekOneCatalog",
    "ToeicQuestionTranslationWeekTwoCatalog",
    "ToeicQuestionTranslationWeekThreeCatalog",
    "ToeicQuestionTranslationSupplementaryCatalog",
    "ToeicQuestionTranslationDay17Catalog",
    "ToeicQuestionTranslationDay18And20Catalog",
)
DAY17_GROUPS=("ONBOARD","RETAIL","SUPPORT","LEASE")
DAY18_GROUPS=("TRAINING","MIGRATION","LICENSE")
DAY20_GROUPS=("PERDIEM","CATERING")


def collect_translations() -> dict[str,tuple[str,str,list[str]]]:
    data:dict[str,tuple[str,str,list[str]]]={}
    for basename in FILES:
        source=(CONTENT/f"{basename}.ets").read_text(encoding="utf-8")
        for raw in literals_after(source,"new ToeicQuestionTranslation("):
            args=fields(raw)
            if len(args)!=4:
                raise AssertionError(f"{basename}: translation must have four constructor arguments")
            question_id=ast.literal_eval(args[0])
            # Existing catalogs sometimes supply shared passage variable names.
            passage=ast.literal_eval(args[1]) if args[1][0] in ("'",'"') else args[1]
            stem=ast.literal_eval(args[2])
            options=ast.literal_eval(args[3])
            if question_id in data:
                raise AssertionError(f"{question_id}: duplicated translation record")
            if not isinstance(options,list) or len(options)!=4:
                raise AssertionError(f"{question_id}: Chinese options must have four items")
            if not stem or not all(isinstance(x,str) and x.strip() for x in options):
                raise AssertionError(f"{question_id}: empty translated stem or option")
            data[question_id]=(passage,stem,options)
    return data


def main() -> None:
    translations=collect_translations()
    questions,_=collect()
    originals={q.id:q for q in questions}
    assert len(translations)==221, f"expected 221 unique question translations: {len(translations)}"
    for question_id,(passage,stem,options) in translations.items():
        assert question_id in originals, f"{question_id}: orphan translation entry"
        assert not question_id.startswith(("R-M1-","R-M2-")), f"{question_id}: mock answer aid must be hidden"
        assert len(options)==len(originals[question_id].choices), f"{question_id}: option index mismatch"
        assert any("\u4e00"<=c<="\u9fff" for c in stem), f"{question_id}: untranslated question stem"
        for i,value in enumerate(options):
            # Monetary amounts / times are intentionally left as numbers;
            # an empty or swapped slot is caught separately by source audits.
            assert value.strip(), f"{question_id}: missing translated option {i}"
    timed={f"R-P7-TIMED-{i}" for i in range(1701,1719)}
    groups_by_day={17:DAY17_GROUPS,18:DAY18_GROUPS,20:DAY20_GROUPS}
    assert timed.issubset(translations), f"Day17: missing timed Chinese translations: {timed-translations.keys()}"
    for day,groups in groups_by_day.items():
        for prefix in groups:
            ids={f"R-P7-{prefix}-0{i}" for i in range(1,6)}
            missing=ids-translations.keys()
            assert not missing,f"Day {day}: missing complete {prefix} group: {missing}"
            passages={translations[x][0] for x in ids}
            assert len(passages)==1 and len(next(iter(passages)))>120, (
                f"Day {day}: {prefix} five questions must share a real complete translated passage")
    # Day21 reuses exactly 15 P5, 8 P6 and 12 P7 items from preceding
    # days, and must not silently introduce unlocalized new IDs.
    week_three=(CONTENT/"ToeicWeekThreeContent.ets").read_text(encoding="utf-8")
    suffix=week_three[week_three.index("static finalCheckQuestionIds()"):
                      week_three.index("static p5SprintQuestions()")]
    import re
    day21=set(re.findall(r'"(R-[A-Z0-9-]+)"',suffix))
    assert len(day21)==35 and day21.issubset(translations), (
        f"Day21 must reuse 35 translated questions: {day21-translations.keys()}")
    preset=(CONTENT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    assert "for (let day=1; day<=21; day++)" in preset
    assert "if (PresetToeicContent.isMockDay(day)) continue;" in preset
    catalog=(CONTENT/"ToeicQuestionTranslationCatalog.ets").read_text(encoding="utf-8")
    for basename in FILES:
        assert f"{basename}.items()" in catalog,f"{basename} missing from runtime catalog"
    print("TOEIC_TRANSLATION_COVERAGE_PASS records=221 day17_timed=18 "
          "day17_extra=20 day18_extra=15 day20_extra=10 day21_reused=35 "
          "mock_translations=0")


if __name__=="__main__":
    main()
