#!/usr/bin/env python3
"""Issue #478: targeted bilingual semantic corrections for hidden aids and drills.

This guards concrete, source-confirmed inclusivity/modality/condition fixes.
Coverage of 221 translations + 70 drills is verified, but is not an independent
full-corpus translation certification, official ETS review, or device test.
"""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path

from validate_toeic_question_quality import collect
from validate_toeic_semantic_issue478 import sentence_drills
from validate_toeic_translation_coverage import collect_translations

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"

# (English original anchor, required Chinese fix, deprecated Chinese expression)
DRILL_CASES = {
    "S-018": ("while electrical repairs are being completed",
              "电气维修进行期间", "电气维修完成期间"),
    "S-033": ("before the end of the month",
              "本月结束前", "月底前续费"),
    "S-043": ("are encouraged to retain",
              "鼓励员工保留", "员工应保留"),
    "S-052": ("orders over $100",
              "超过 100 美元", "满 100 美元"),
    "S-058": ("provide separate evidence",
              "分别提供关于经验与可到岗时间的证据", "分别证明经验与到岗时间"),
    "S-059": ("defines a prerequisite",
              "说明先修条件", "规定前置课"),
    "S-063": ("whose orders cannot be delivered",
              "订单无法按原定日期送达的顾客", "订单客户"),
    "S-066": ("before reading the rest of the paragraph again",
              "再重读该段其余内容", "决定是否需要重读"),
    "S-069": ("may appear as a synonym",
              "题干中的某个名词", "题干中重复出现的名词"),
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError("TOEIC_ISSUE478_BILINGUAL_FAIL: " + message)


def check_drills(drills: dict) -> None:
    require(len(drills) == 70, "70 unique sentence drills required")
    require(set(drills) == {f"S-{n:03d}" for n in range(1, 71)},
            "sentence ID sequence changed")
    for key, (source, corrected, obsolete) in DRILL_CASES.items():
        english, chinese, guidance = drills[key]
        require(source in english, f"{key}: English source changed, re-review needed")
        require(corrected in chinese, f"{key}: missing reviewed Chinese correction")
        require(obsolete not in chinese and obsolete not in guidance,
                f"{key}: old semantic error survives in Chinese teaching content")
    # Answer-bound quote from original: over (>) differs from at least (>=).
    require("超过100美元" in drills["S-052"][2] and
            "满100美元" not in drills["S-052"][2],
            "S-052: drill guidance must preserve strict-over threshold")
    require("鼓励员工" in drills["S-043"][2],
            "S-043: English encouragement must not become an obligation")
    require("分别提供" in drills["S-058"][2],
            "S-058: potential evidence should not be translated as proof")


def check_translations(translations: dict, questions: dict) -> None:
    require(len(translations) == 221, "221 original translations required")
    by_friday = questions["R-P5-COL-0005"]
    require("by Friday" in by_friday.stem, "R-P5-COL-0005: source no longer uses by")
    require("最迟于周五（含当天）" in translations[by_friday.id][1],
            "R-P5-COL-0005: by Friday includes Friday")
    interview = questions["R-P7-DETAIL-0004"]
    require("by October 10" in interview.passage,
            "R-P7-DETAIL-0004: source no longer uses by")
    zh_article, zh_stem, _ = translations[interview.id]
    require("最迟将在10月10日收到联系" in zh_article and
            "谁最迟会在10月10日收到联系" in zh_stem,
            "R-P7-DETAIL-0004: by October 10 includes October 10")
    timed_source = (CONTENT / "ToeicWeekThreeContent.ets").read_text(encoding="utf-8")
    require("by 10:00" in timed_source and "R-P7-TIMED-1705" in timed_source,
            "Day17 visit source deadline no longer verifiable")
    for number in (1704, 1705, 1706):
        key = f"R-P7-TIMED-{number}"
        passage = translations[key][0]
        require("最迟在10:00将产品样品准备好" in passage and
                "请在10:00前将产品样品准备好" not in passage,
                f"{key}: by 10:00 must include 10:00")
    hire_source = (CONTENT / "ToeicExtraReadingBatchTwo.ets").read_text(encoding="utf-8")
    require("by 5:00 P.M. on January 8" in hire_source and
            "before 8:45 A.M." in hire_source,
            "new hire source must distinguish by and before")
    for number in range(1, 6):
        key = f"R-P7-ONBOARD-{number:02d}"
        passage = translations[key][0]
        require("最迟必须于1月8日下午5点完成线上报名" in passage,
                f"{key}: registration by 5 PM must be inclusive")
        require("上午8:45前向安保部门领取当日通行证" in passage,
                f"{key}: day pass before 8:45 must remain strictly earlier")
        require("1月8日下午5点前完成线上报名" not in passage,
                f"{key}: old registration cutoff language survived")
    # Other real test: strictly over $75 is correctly rendered, not >=$75.
    zh = translations["R-P7-PARA-0503"][0]
    require("超过75美元" in zh, "strictly over $75 boundary regressed")


def validate() -> None:
    drills = sentence_drills()
    translations = collect_translations()
    rows, _ = collect()
    questions = {question.id: question for question in rows}
    check_drills(drills)
    check_translations(translations, questions)

    bad_drills = dict(drills)
    english, _, tip = bad_drills["S-052"]
    bad_drills["S-052"] = (english, "广告规定满 100 美元免运费。", tip)
    try:
        check_drills(bad_drills)
    except AssertionError as error:
        require("S-052" in str(error), "drill negative test failed for wrong reason")
    else:
        raise AssertionError("TOEIC_ISSUE478_BILINGUAL_FAIL: invalid threshold passed")

    bad_translations = deepcopy(translations)
    passage, stem, options = bad_translations["R-P7-TIMED-1705"]
    bad_translations["R-P7-TIMED-1705"] = (
        passage.replace("最迟在10:00", "在10:00前"), stem, options
    )
    try:
        check_translations(bad_translations, questions)
    except AssertionError as error:
        require("1705" in str(error), "translation negative test failed for wrong reason")
    else:
        raise AssertionError("TOEIC_ISSUE478_BILINGUAL_FAIL: by/before mixup passed")

    print("TOEIC_ISSUE478_BILINGUAL_SEMANTIC_PASS "
          "translations_checked=221 drills_checked=70 "
          "corrected_drills=9 corrected_translations=10 "
          "boundary_modality_negative_cases=2 expert_certified=NO")


if __name__ == "__main__":
    validate()
