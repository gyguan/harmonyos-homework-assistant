#!/usr/bin/env python3
"""Issue #478 P1 final closeout gate: 185 original P5/P6 + 300 vocabulary.

This validates static evidence produced by an AI editorial second pass. It does
NOT claim ETS/human certification. It fails closed if reviewed source content,
archive/replacement routing, vocabulary semantics, examples, or IPA drift.
"""
from __future__ import annotations
import ast
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/"entry/src/main/ets/toeic/content"
QLEDGER=ROOT/"docs/product/toeic-issue478-p1-final-question-review-2026-10-09.json"
VLEDGER=ROOT/"docs/product/toeic-issue478-p1-final-vocabulary-review-2026-10-09.json"
QFILES=["PresetToeicContent","ToeicWeekOneContent","ToeicWeekTwoContent","ToeicWeekThreeContent","ToeicStandardDiagnosticContent"]
VFILES=["PresetToeicContent","ToeicWeekOneContent","ToeicVocabularyExpansion","ToeicVocabularyBatchTwo","ToeicVocabularyBatchThree","ToeicVocabularyBatchFour","ToeicVocabularyBatchFive","ToeicVocabularyBatchSix","ToeicVocabularyBatchSeven"]

def calls(src:str,sig:str)->list[str]:
    out=[]; cur=0
    while (start:=src.find(sig,cur))>=0:
        pos=start+len(sig); depth=1; quote=""; esc=False
        for end in range(pos,len(src)):
            ch=src[end]
            if quote:
                if esc: esc=False
                elif ch=="\\": esc=True
                elif ch==quote: quote=""
            elif ch in ("'",'"'): quote=ch
            elif ch=="(": depth+=1
            elif ch==")":
                depth-=1
                if depth==0:
                    out.append(src[pos:end]);cur=end+1;break
        else: raise AssertionError("unterminated call")
    return out

def fields(text:str)->list[str]:
    out=[];start=0;depth=0;quote="";esc=False
    for i,ch in enumerate(text):
        if quote:
            if esc: esc=False
            elif ch=="\\":esc=True
            elif ch==quote:quote=""
        elif ch in ("'",'"'):quote=ch
        elif ch in "([{":depth+=1
        elif ch in ")]}":depth-=1
        elif ch=="," and depth==0:
            out.append(text[start:i].strip());start=i+1
    out.append(text[start:].strip());return out

def val(x:str):
    return ast.literal_eval(x) if x.startswith(("'",'"',"[")) else x

def digest(obj:dict)->str:
    raw=json.dumps(obj,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return hashlib.sha256(raw.encode()).hexdigest()

def questions()->dict[str,dict]:
    rows={}
    for name in QFILES:
        src=(CONTENT/f"{name}.ets").read_text(encoding="utf-8")
        wrapper=name in {"ToeicWeekTwoContent","ToeicWeekThreeContent"}
        sig=f"{name}.q(" if wrapper else "new ToeicQuestion("
        for raw in calls(src,sig):
            f=[val(x) for x in fields(raw)]
            if not f or not isinstance(f[0],str) or not f[0].startswith("R-"):continue
            shift=0 if wrapper else 1
            part=str(f[1+shift]).split(".")[-1]
            if part not in {"PART_5","PART_6"}:continue
            row={"id":f[0],"part":part,"skill":str(f[2+shift]).split(".")[-1],
                 "passage":f[3+shift],"stem":f[4+shift],"options":f[5+shift],
                 "answer":int(f[6+shift]),"explanation":f[7+shift],
                 "evidence":f[8+shift],"paraphrase":f[9+shift]}
            row["contentSha256"]=digest(row)
            if row["id"] in rows:raise AssertionError("duplicate question "+row["id"])
            rows[row["id"]]=row
    assert len(rows)==185, f"original P5/P6 count {len(rows)} != 185"
    return rows

def vocabulary()->dict[str,dict]:
    extras={}
    esrc=(CONTENT/"ToeicVocabularyExampleCatalog.ets").read_text(encoding="utf-8")
    for raw in calls(esrc,"new ToeicVocabularyExample("):
        f=[val(x) for x in fields(raw)];extras[f[0]]=f[1]
    psrc=(CONTENT/"ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    ipas=dict(re.findall(r"new ToeicPronunciationEntry\('(V-\d{3})','([^']+)'",psrc))
    assert len(ipas)==300,f"IPA count {len(ipas)} != 300"
    rows={}
    for name in VFILES:
        src=(CONTENT/f"{name}.ets").read_text(encoding="utf-8")
        for raw in calls(src,"new ToeicVocabularyItem("):
            f=[val(x) for x in fields(raw)]
            if not f or not isinstance(f[0],str) or not re.fullmatch(r"V-\d{3}",f[0]):continue
            example=(f[11] if len(f)>11 and isinstance(f[11],str) else "") or extras.get(f[0],"")
            row={"id":f[0],"word":f[1],"pos":f[2],"meaning":f[3],
                 "level":str(f[4]).split(".")[-1],"scene":f[5],
                 "collocations":f[6],"synonyms":f[7],"example":example,
                 "ipa":ipas[f[0]]}
            row["contentSha256"]=digest(row)
            if row["id"] in rows:raise AssertionError("duplicate vocab "+row["id"])
            rows[row["id"]]=row
    assert set(rows)=={f"V-{i:03d}" for i in range(1,301)}
    return rows

def validate()->None:
    qsrc=questions();vsrc=vocabulary()
    q=json.loads(QLEDGER.read_text(encoding="utf-8"))
    v=json.loads(VLEDGER.read_text(encoding="utf-8"))
    assert q["reviewMode"]=="AI_EDITORIAL_SECOND_PASS" and q["expertCertification"]=="NO"
    assert v["reviewMode"]=="AI_EDITORIAL_SECOND_PASS" and v["expertCertification"]=="NO"
    assert q["count"]==185 and len(q["items"])==185
    assert v["count"]==300 and len(v["items"])==300
    assert q["passCount"]==171 and q["archivedReplacedCount"]==14
    assert v["passCount"]==288 and v["correctedCount"]==12
    qrows={x["id"]:x for x in q["items"]};vrows={x["id"]:x for x in v["items"]}
    assert set(qrows)==set(qsrc) and set(vrows)==set(vsrc)
    for id,src in qsrc.items():
        rev=qrows[id]
        assert rev["reviewer"]=="AI-GPT5.6-SOL" and rev["reviewedAt"]=="2026-10-09"
        assert rev["contentSha256"]==src["contentSha256"],f"{id}: reviewed question source drift"
        assert rev["decision"] in {"PASS_AI_SECOND_PASS","ARCHIVED_REPLACED"}
        wrong=[i for i in range(4) if i!=src["answer"]]
        assert [x["index"] for x in rev["wrongOptions"]]==wrong
        assert all(x["verdict"]=="REJECTED_AFTER_CONTEXTUAL_COMPARISON" for x in rev["wrongOptions"])
        if rev["decision"]=="ARCHIVED_REPLACED": assert rev["replacementId"]
        else: assert rev["replacementId"] is None
    for id,src in vsrc.items():
        rev=vrows[id]
        assert rev["reviewer"]=="AI-GPT5.6-SOL" and rev["reviewedAt"]=="2026-10-09"
        assert rev["contentSha256"]==src["contentSha256"],f"{id}: reviewed vocabulary source drift"
        assert rev["decision"] in {"PASS_AI_SECOND_PASS","PASS_AFTER_CORRECTION"}
        assert len(rev["checks"])==6 and rev["ipa"]==src["ipa"] and rev["example"]==src["example"]

    preset=(CONTENT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    final=(CONTENT/"ToeicP1FinalQuestionCorrections.ets").read_text(encoding="utf-8")
    translations=(CONTENT/"ToeicQuestionTranslationCatalog.ets").read_text(encoding="utf-8")
    replacements={x["id"]:x["replacementId"] for x in q["items"] if x["replacementId"]}
    all_sources="\n".join(p.read_text(encoding="utf-8") for p in CONTENT.glob("*.ets"))
    for old,new in replacements.items():
        assert f"question.id==='{old}'" in preset,f"{old}: archived item is not excluded from live queues"
        assert new in all_sources,f"{old}: missing replacement {new}"
    for id in ("R-FP1-P5-1528","R-FP1-P6-1606","R-FP1-DX-P5-05","R-FP1-M2-P5-010","R-FP1-M2-P6-002"):
        assert id in final and f"questionId==='{id}'" in translations
    assert "id==='R-P5-SPRINT-1528' ? 'R-FP1-P5-1528'" not in preset  # block mapping uses explicit branch
    assert "if (id==='R-P5-SPRINT-1528') return 'R-FP1-P5-1528';" in preset
    assert "if (id==='R-P6-SPRINT-1606') return 'R-FP1-P6-1606';" in preset
    # Malformed historical distractors may remain only for saved reports; their
    # IDs are quarantined, and final replacements use valid English forms.
    assert "['receives','is received','has received','receiving']" in final
    assert '["it","its","itself","it\'s"]' in final or "['it','its','itself',\"it's\"]" in final
    assert "['arrive','arrived','will arrive','arrival']" in final
    assert "['send','was sent','had sent','sending']" in final

    # Exact corrected lexical boundaries from this final batch.
    expected={
      "V-156":("研讨会；专题讲座",["meeting for study and discussion"]),
      "V-157":("新员工入职与融入组织的流程；入职培训",["process of integrating new employees into an organization"]),
      "V-179":("营收；收入",["income received by a business or government"]),
      "V-189":("货物托盘",["flat platform for stacking and moving goods"]),
      "V-285":("承包商",["person or company hired under a contract to do work"]),
    }
    for id,(meaning,synonyms) in expected.items():
        assert vsrc[id]["meaning"]==meaning and vsrc[id]["synonyms"]==synonyms
        assert vrows[id]["decision"]=="PASS_AFTER_CORRECTION"
    print("TOEIC_ISSUE478_P1_FINAL_PASS questions=185 pass=171 archived_replaced=14 vocabulary=300 pass=288 corrected=12 reviewer=AI-GPT5.6-SOL expert_certification=NO")

if __name__=="__main__":
    validate()
