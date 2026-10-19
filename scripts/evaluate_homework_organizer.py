#!/usr/bin/env python3
"""Offline AI homework organizer regression scoring. Standard library only.

Only cases with reviewStatus=VERIFIED are scored. Draft examples can document
edge cases, but must never be represented as teacher-validated ground truth.
The title/instruction keyword metric is a transparent proxy, not semantic accuracy.
"""
import argparse
import json
import hashlib
from organizer_metrics import summarize
from collections import defaultdict
from pathlib import Path


def read_json(path):
    with Path(path).open(encoding="utf-8") as f:
        return json.load(f)


def normalize(value):
    return "".join(str(value or "").lower().split())


def match(expected, predicted):
    if normalize(expected["subject"]) != normalize(predicted.get("subject")):
        return False
    body = normalize(str(predicted.get("title") or "") + " " +
                     str(predicted.get("instruction") or ""))
    keys = expected.get("keywords", [])
    return bool(keys) and all(normalize(x) in body for x in keys)


def evaluate(fixtures, predictions):
    results = predictions.get("results", [])
    by_id = {p["caseId"]: p for p in results}
    if len(by_id) != len(results):
        raise ValueError("Duplicate prediction case IDs")
    fixture_hash = hashlib.sha256(json.dumps(fixtures, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    performance = summarize(results)
    buckets = {kind: summarize([r for r in results if r.get("inputType", "UNSPECIFIED") == kind])
               for kind in sorted({r.get("inputType", "UNSPECIFIED") for r in results})}
    cases = fixtures.get("cases", [])
    if len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Duplicate case IDs in fixtures")
    verified = [case for case in cases if case.get("reviewStatus") == "VERIFIED"]
    if not verified:
        return {
            "status": "NO_VERIFIED_GOLD",
            "warning": "No parent-verified cases. Do not calculate or report model accuracy.",
            "fixtureHash": fixture_hash, "performance": performance, "buckets": buckets,
            "fixtureCount": len(cases),
            "verifiedCount": 0,
            "cases": []
        }
    missing_prediction = [c["id"] for c in verified if c["id"] not in by_id]
    if missing_prediction:
        raise ValueError("Missing model output for verified cases: " +
                         ", ".join(missing_prediction))
    rows = []
    totals = defaultdict(int)
    by_teacher = defaultdict(lambda: defaultdict(int))
    model_names = set()
    prompt_versions = set()
    for case in verified:
        prediction = by_id[case["id"]]
        outputs = prediction.get("assignments", [])
        gold = case["expected"]
        if not isinstance(outputs, list) or not isinstance(gold, list):
            raise ValueError("Expected list output for " + case["id"])
        if any(not item.get("keywords") or not item.get("subject") for item in gold):
            raise ValueError("Verified case has empty expected subject/keywords: " + case["id"])
        used = set()
        # Maximum bipartite matching, not order-sensitive greedy assignment.
        edges = [[i for i, out in enumerate(outputs) if match(exp, out)] for exp in gold]
        owners = {}
        def assign(g, visited):
            for i in edges[g]:
                if i in visited:
                    continue
                visited.add(i)
                if i not in owners or assign(owners[i], visited):
                    owners[i] = g
                    return True
            return False
        for g in range(len(gold)):
            assign(g, set())
        matched_gold = set(owners.values())
        field_checks = []
        evidence_checks = []
        blocks = {b.get("id") for b in prediction.get("sourceDocument", {}).get("blocks", []) if b.get("text")}
        for i, g in owners.items():
            exp, out = gold[g], outputs[i]
            for field, value in exp.get("fields", {}).items():
                field_checks.append(normalize(out.get(field)) == normalize(value))
            required = set(exp.get("sourceBlockIds", []))
            if required:
                evidence_checks.append(required <= set(out.get("sourceBlockIds", [])) and required <= blocks)
        totals["fieldCorrect"] += sum(field_checks)
        totals["fieldTotal"] += len(field_checks) + sum(len(gold[g].get("fields", {})) for g in range(len(gold)) if g not in matched_gold)
        totals["evidenceCorrect"] += sum(evidence_checks)
        totals["evidenceTotal"] += len(evidence_checks) + sum(bool(gold[g].get("sourceBlockIds")) for g in range(len(gold)) if g not in matched_gold)
        totals["evidenceCovered"] += sum(bool(o.get("sourceBlockIds")) and set(o["sourceBlockIds"]) <= blocks for o in outputs)
        unmatched_gold = []
        used = set(owners)
        unmatched_gold = [gold[g] for g in range(len(gold)) if g not in matched_gold]
        extras = [outputs[i] for i in range(len(outputs)) if i not in used]
        teacher = case.get("teacherKey", "UNSPECIFIED")
        row = {
            "caseId": case["id"], "teacherKey": teacher,
            "matched": len(used), "expectedCount": len(gold),
            "predictedCount": len(outputs), "countExact": len(outputs) == len(gold),
            "missing": unmatched_gold, "unmatchedOutputs": extras,
        }
        if isinstance(prediction.get("elapsedMs"), (float, int)):
            row["elapsedMs"] = prediction["elapsedMs"]
        if isinstance(prediction.get("tokens"), int):
            row["tokens"] = prediction["tokens"]
        rows.append(row)
        model_names.add(prediction.get("model", "UNSPECIFIED"))
        prompt_versions.add(prediction.get("promptVersion", "UNSPECIFIED"))
        for key, value in (("matched", len(used)), ("expected", len(gold)),
                           ("predicted", len(outputs)), ("countExact", int(row["countExact"]))):
            totals[key] += value
            by_teacher[teacher][key] += value
    if len(model_names) != 1 or len(prompt_versions) != 1:
        raise ValueError("Mixed model or prompt versions: report each variant separately")

    def score(counts):
        expected, predicted, matched = counts["expected"], counts["predicted"], counts["matched"]
        return {
            "matched": matched, "expected": expected, "predicted": predicted,
            "recallProxy": round(matched / expected, 4) if expected else None,
            "precisionProxy": round(matched / predicted, 4) if predicted else None,
            "exactTaskCountCases": counts["countExact"],
        }

    return {
        "status": "SCORED_KEYWORD_PROXY",
        "warning": "Keyword coverage is a deterministic proxy, not verified semantic accuracy.",
        "fixtureCount": len(cases), "verifiedCount": len(verified),
        "model": next(iter(model_names)), "promptVersion": next(iter(prompt_versions)),
        "fixtureHash": fixture_hash, "performance": performance, "buckets": buckets,
        "total": dict(score(totals),
                      keyFieldAccuracy=round(totals["fieldCorrect"] / totals["fieldTotal"], 4) if totals["fieldTotal"] else None,
                      evidenceAccuracy=round(totals["evidenceCorrect"] / totals["evidenceTotal"], 4) if totals["evidenceTotal"] else None,
                      evidenceCoverage=round(totals["evidenceCovered"] / totals["predicted"], 4) if totals["predicted"] else None),
        "teachers": {teacher: score(values) for teacher, values in by_teacher.items()},
        "cases": rows,
    }


def compare(prior, candidate):
    if prior.get("fixtureHash") != candidate.get("fixtureHash") or not candidate.get("fixtureHash"):
        raise ValueError("Baseline must use identical fixture content/status/annotations")
    if prior.get("status") != candidate.get("status"):
        raise ValueError("Baseline and candidate gold status differs")
    deltas = {}
    regression = False
    for key in ("recallProxy", "precisionProxy", "keyFieldAccuracy", "evidenceAccuracy", "evidenceCoverage"):
        old, new = prior.get("total", {}).get(key), candidate.get("total", {}).get(key)
        deltas[key] = new - old if old is not None and new is not None else None
        regression |= old is not None and (new is None or new < old)
    for key in ("p50Ms", "p95Ms", "averageTokensIn", "averageTokensOut", "reviewRate", "failureRate"):
        old, new = prior.get("performance", {}).get(key), candidate.get("performance", {}).get(key)
        deltas[key] = new - old if old is not None and new is not None else None
    return {"regressed": regression, "baselineDeltas": deltas,
            "comparisonNote": "Confirm identical model, hardware/network, date and teacher/experience setup before attributing latency changes."}


def performance_gate(prior, candidate):
    old, new = prior.get("performance", {}), candidate.get("performance", {})
    required = ("p50Ms", "p95Ms", "failureRate", "averageTokensIn", "averageTokensOut")
    if any(old.get(k) is None or new.get(k) is None for k in required):
        return "UNAVAILABLE"
    # Partial usage cannot silently pass a cost gate.
    if old.get("usageUnavailableRequests", 0) or new.get("usageUnavailableRequests", 0):
        return "UNAVAILABLE"
    if any(new[k] > old[k] for k in ("p50Ms", "p95Ms", "failureRate")):
        return "REGRESSED"
    if new["averageTokensIn"] + new["averageTokensOut"] > old["averageTokensIn"] + old["averageTokensOut"]:
        return "REGRESSED"
    return "PASS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--predictions", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--baseline", type=Path,
                        help="Optional prior report, scored against the identical verified cases")
    parser.add_argument("--enforce-performance", action="store_true",
                        help="Fail if measured P50/P95, failure rate or total average tokens regress; unavailable data cannot pass")
    args = parser.parse_args()
    result = evaluate(read_json(args.fixtures), read_json(args.predictions))
    if args.baseline:
        prior = read_json(args.baseline)
        result.update(compare(prior, result))
        if args.enforce_performance:
            result["performanceGate"] = performance_gate(prior, result)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                               encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result["status"] != "SCORED_KEYWORD_PROXY":
        raise SystemExit(2)
    if result.get("regressed") or result.get("performanceGate") == "REGRESSED":
        raise SystemExit(1)
    if result.get("performanceGate") == "UNAVAILABLE":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
