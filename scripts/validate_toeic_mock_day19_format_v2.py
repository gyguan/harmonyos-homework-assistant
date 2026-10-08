#!/usr/bin/env python3
"""Day19 mock v2 format and paper/version preservation gate.

Official Reading structure: P5 30, P6 4x4, P7 singles 10 texts/29 items,
P7 multi 5 texts/25 items; reuse of stable v1 IDs is forbidden.
"""
from __future__ import annotations
import json
import re
from collections import Counter
from pathlib import Path
from validate_toeic_question_quality import collect,fields,literals_after,parse_question
from validate_toeic_answer_display import display_order

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/"entry/src/main/ets/toeic/content"
SRC=(CONTENT/"ToeicMockDay19V2Content.ets").read_text(encoding="utf-8")


def validate() -> None:
    questions,_=collect()
    existing={q.id:q for q in questions}
    old_p5=[q for q in questions if q.id.startswith("R-M2-P5-")]
    old_p6=[q for q in questions if q.id.startswith("R-M2-P6-")]
    old_p7=[q for q in questions if q.id.startswith("R-M2-P7-")]
    assert len(old_p5)==30 and len(old_p6)==16 and len(old_p7)==54
    assert sorted(Counter(q.passage for q in old_p6).values())==[4,4,4,4], (
        "Day19 Part6 must comprise four related four-item passages")
    assert "for(let i=0;i<18;i++)" in SRC and "old=legacy[46+i]" in SRC
    assert "for(let group=0;group<5;group++)" in SRC
    assert "old=legacy[64+group*3+item]" in SRC
    assert "rotation=(item-old.correctIndex+4)%4" in SRC
    assert "(old.correctIndex+rotation)%4" not in SRC or "choices,item,old.explanation" in SRC
    authored=[]
    for raw in literals_after(SRC,"new ToeicQuestion("):
        args=fields(raw)
        if args and re.fullmatch(r"""(?:'[^']+'|"[^"]+")""",args[0]):
            item=parse_question(args,"ToeicMockDay19V2Content",False)
            assert item is not None
            authored.append(item)
    assert len(authored)==21,f"expected 11 single + 10 multi authored items, found {len(authored)}"
    singles=[q for q in authored if "-S" in q.id]
    multiples=[q for q in authored if "-M" in q.id]
    assert len(singles)==11 and len(multiples)==10
    assert sorted(Counter(q.id.split("-")[3] for q in singles).values())==[2,3,3,3]
    assert any(q.id=="R-FM2-P7-S07-03" and
               "[4]" in q.passage and "[4]" in q.choices
               and q.answer==3 for q in singles), "sentence location coverage missing"
    active_ids=[f"R-FM2-P7-S{p:02d}-{q:02d}" for p in range(1,7) for q in range(1,4)]
    active_ids += [f"R-FM2-P7-S{p:02d}-{q:02d}" for p,sz in ((7,3),(8,3),(9,3),(10,2))
                   for q in range(1,sz+1)]
    active_ids += [f"R-FM2-P7-M{p}-{q:02d}" for p in range(1,6) for q in range(1,6)]
    assert len(active_ids)==54 and len(set(active_ids))==54
    assert len([x for x in active_ids if "-S" in x])==29
    assert len([x for x in active_ids if "-M" in x])==25
    assert {q.id for q in authored}.issubset(active_ids)
    evidence=re.search(r"let evidence:string\[\]\[\]=(\[\[.*?\]\]);",SRC)
    markers=re.search(r"let markers:string\[\]\[\]=(\[\[.*?\]\]);",SRC)
    assert evidence and markers,"document splitting and evidence matrix missing"
    evidence=json.loads(evidence.group(1)); markers=json.loads(markers.group(1))
    assert len(evidence)==len(markers)==5
    passage_sizes=[]
    for n in range(5):
        source_id=f"R-M2-P7-{chr(71+n)}-01"
        passage=existing[source_id].passage
        offsets=[0]+[passage.index(marker)+2 for marker in markers[n]]
        docs=[passage[offsets[i]:(offsets[i+1] if i+1<len(offsets) else len(passage))].strip()
              for i in range(len(offsets))]
        assert len(docs) in (2,3),f"{source_id}: two or three real documents required"
        passage_sizes.append(len(docs))
        for k,raw in enumerate(evidence[n]):
            fragments=raw.split(" || ")
            assert all(any(part in doc for doc in docs) for part in fragments),(
                f"{source_id} legacy citation {k+1} missing from linked documents")
            # The first question in G/H/I/J/K exercises cross-document reasoning.
            if k==0:
                seen={i for part in fragments for i,doc in enumerate(docs) if part in doc}
                assert len(seen)>=2,f"{source_id}: missing multi-document proof"
        for question in multiples:
            if question.group==f"FM2-G{n+1}":
                assert all(any(part in doc for doc in docs)
                           for part in question.evidence.split(" || ")),(
                    f"{question.id}: orphan answer evidence")
    assert passage_sizes.count(2)==2 and passage_sizes.count(3)==3, (
        f"Day19 requires exactly two double and three triple passages: {passage_sizes}")
    assert sorted(Counter(q.group for q in multiples).values())==[2]*5
    preset=(CONTENT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    service=(ROOT/"entry/src/main/ets/toeic/application/ToeicReadingGroupService.ets").read_text(encoding="utf-8")
    for token in ("ToeicWeekThreeContent.mockQuestionIds().slice(0,46)",
                  "for (let question of ToeicMockDay19V2Content.questions()) ids.push(question.id)",
                  "ToeicMockDay19V2Content.questions()","ToeicMockDay19V2Content.groups()"):
        assert token in preset,f"Day19 runtime paper assembly missing {token}"
    assert "ToeicMockDay19V2Content.groups()" in service
    assert "let result:ToeicQuestion[]=[];" in SRC
    # Active v2 answer-position distribution, independent of archived R-M2 paper.
    displayed=[(q.id,q.answer) for q in old_p5+old_p6]
    displayed.extend((f"R-FM2-P7-S{i//3+1:02d}-{i%3+1:02d}",old_p7[i].answer)
                     for i in range(18))
    displayed.extend((f"R-FM2-P7-M{g+1}-{item+1:02d}",item)
                     for g in range(5) for item in range(3))
    displayed.extend((q.id,q.answer) for q in authored)
    assert len(displayed)==100 and len({x[0] for x in displayed})==100
    counts=Counter(display_order(id).index(index) for id,index in displayed)
    p7counts=Counter(display_order(id).index(index) for id,index in displayed[46:])
    assert all(18<=counts[i]<=32 for i in range(4)),f"Day19 v2 display bias: {counts}"
    assert all(8<=p7counts[i]<=19 for i in range(4)),f"Day19 v2 P7 bias: {p7counts}"
    print("TOEIC_MOCK_DAY19_V2_DISPLAY_PASS " + " ".join(f"{chr(i+65)}={counts[i]}" for i in range(4)))
    print("TOEIC_MOCK_DAY19_V2_FORMAT_PASS questions=100 P5=30 P6=16_4x4 "
          "P7_single=29_10sets P7_multi=25_5x5 multi_docs=2double_3triple evidence=verbatim "
          "legacy_v1=preserved")


if __name__=="__main__":
    validate()
