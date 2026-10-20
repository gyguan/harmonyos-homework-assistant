#!/usr/bin/env python3
"""Compare fixed-corpus replays without invoking models or selecting a production model.

Reuses the gold-only evaluator. Source image bytes, case coverage, repeated-run distribution,
actual model/prompt/experience provenance and declared environment must be comparable.
"""
import argparse
import json
import re
from datetime import date
from collections import defaultdict
from pathlib import Path
from evaluate_homework_organizer import evaluate, read_json
from organizer_eval_inputs import case_fingerprint, digest
from organizer_metrics import summarize, numeric

METRICS = ('recallProxy', 'precisionProxy', 'keyFieldAccuracy', 'evidenceAccuracy', 'evidenceCoverage')
CONTEXT = ('studentScopeHash', 'teacherStateHash', 'textbookStateHash', 'businessDate', 'networkProfile')


def quality(reports):
    counts = defaultdict(int)
    for report in reports:
        for key, value in report.get('counts', {}).items():
            counts[key] += value
    def ratio(correct, total):
        return round(counts[correct]/counts[total], 6) if counts[total] else None
    return dict(recallProxy=ratio('matched', 'expected'), precisionProxy=ratio('matched', 'predicted'),
                keyFieldAccuracy=ratio('fieldCorrect', 'fieldTotal'), evidenceAccuracy=ratio('evidenceCorrect', 'evidenceTotal'),
                evidenceCoverage=ratio('evidenceCovered', 'predicted'))


def lower_gate(prior, current, keys):
    if any(not numeric(prior.get(k)) or not numeric(current.get(k)) for k in keys):
        return 'UNAVAILABLE'
    return 'REGRESSED' if any(current[k] > prior[k] for k in keys) else 'PASS'


def cost_gate(prior, current):
    currency = prior.get('costCurrency')
    complete = (isinstance(currency, str) and re.fullmatch('[A-Z]{3}', currency) and currency == current.get('costCurrency')
                and not prior.get('costUnavailableRequests') and not current.get('costUnavailableRequests'))
    return lower_gate(prior, current, ('averageConfiguredCost',)) if complete else 'UNAVAILABLE'


def context_valid(context):
    try:
        date.fromisoformat(context.get('businessDate', ''))
    except (ValueError, TypeError, AttributeError):
        return False
    return (isinstance(context, dict) and all(isinstance(context.get(k), str) and context[k] for k in CONTEXT)
            and all(re.fullmatch('[a-f0-9]{64}', context[k]) for k in CONTEXT[:3])
            and re.fullmatch(r'\d{4}-\d{2}-\d{2}', context['businessDate'])
            and re.fullmatch(r'[A-Za-z0-9_.:-]{1,80}', context['networkProfile']))


def benchmark(fixtures, variants, baseline, prices=None, root=Path('.'), comparison_kind='MODEL'):
    if baseline not in variants or len(variants) < 2:
        raise ValueError('Provide baseline and at least one candidate')
    if comparison_kind not in ('MODEL', 'PIPELINE'):
        raise ValueError('Comparison kind must be MODEL or PIPELINE')
    cases = fixtures['cases']
    ids = [case['id'] for case in cases]
    if len(set(ids)) != len(ids) or not ids:
        raise ValueError('Fixture case IDs must be nonempty and unique')
    repeats = {len(runs) for runs in variants.values()}
    if len(repeats) != 1 or not next(iter(repeats)):
        raise ValueError('All variants require the same nonzero number of complete runs')
    fixture_hash = digest(fixtures)
    expected_inputs, input_missing = {}, []
    for case in cases:
        try:
            expected_inputs[case['id']] = case_fingerprint(case, root)
        except (ValueError, OSError):
            input_missing.append(case['id'])
    scored = {}
    raw = {}
    per_case = {}
    contexts = {}
    for name, runs in variants.items():
        if not re.fullmatch('[A-Za-z0-9_.-]{1,80}', name):
            raise ValueError('Variant names must be safe identifiers')
        rows, reports, context_issues, scores = [], [], [], {}
        model_by_type = defaultdict(set)
        for repeat, run in enumerate(runs):
            entries = run.get('results', [])
            if len(entries) != len(ids) or {r['caseId'] for r in entries} != set(ids):
                raise ValueError('Each run must cover exactly the fixed case matrix: ' + name)
            if run.get('fixtureHash') != fixture_hash:
                context_issues.append('FIXTURE_HASH_MISSING_OR_CHANGED')
            context = run.get('benchmarkContext', {})
            if not context_valid(context):
                context_issues.append('CONTROLLED_CONTEXT_UNAVAILABLE')
            contexts[name, repeat] = context
            index = {row['caseId']: row for row in entries}
            for case in cases:
                row = dict(index[case['id']])
                ident, kind = case['id'], case.get('sourceType', 'TEXT')
                if row.get('inputFingerprint') != expected_inputs.get(ident) or ident in input_missing:
                    context_issues.append('INPUT_FINGERPRINT_UNAVAILABLE_OR_CHANGED')
                if row.get('inputType') != kind:
                    context_issues.append('INPUT_TYPE_MISMATCH')
                row['inputType'] = kind
                if not isinstance(row.get('success'), bool):
                    context_issues.append('SUCCESS_STATUS_UNAVAILABLE')
                if row.get('success') is False and row.get('assignments'):
                    raise ValueError('Failed requests must not claim successful assignments')
                if row.get('success'):
                    for key in ('model', 'promptVersion', 'ruleVersion', 'experienceVersion'):
                        if row.get(key) in (None, '', 'unavailable', 'UNSPECIFIED', 'UNAVAILABLE'):
                            context_issues.append('MODEL_PROVENANCE_UNAVAILABLE')
                    model_by_type[kind].add(row.get('model'))
                    first = raw.get((name, 0, ident))
                    if first and first.get('success') and any(row.get(k) != first.get(k) for k in ('model', 'promptVersion', 'ruleVersion', 'experienceVersion')):
                        context_issues.append('PROVENANCE_DRIFT_ACROSS_REPEATS')
                if not numeric(row.get('elapsedMs')):
                    context_issues.append('LATENCY_UNAVAILABLE')
                if not isinstance(row.get('cacheHit'), bool):
                    context_issues.append('CACHE_STATE_UNAVAILABLE')
                if type(row.get('callCount')) is not int or row['callCount'] < 0:
                    context_issues.append('CALL_COUNT_UNAVAILABLE')
                if row.get('cacheHit') is True and row.get('callCount') != 0:
                    context_issues.append('CACHE_CALL_COUNT_CONTRADICTION')
                calls = row.get('aiCalls')
                if row.get('success') and not row.get('cacheHit') and (not isinstance(calls, list) or not calls or row.get('callCount') != len(calls)):
                    context_issues.append('CALL_USAGE_PROVENANCE_UNAVAILABLE')
                if numeric(row.get('callCount')) and row['callCount'] > 2:
                    context_issues.append('CALL_BUDGET_EXCEEDED')
                if isinstance(calls, list) and calls:
                    if any(not isinstance(call, dict) or call.get('promptVersion') in (None, '', 'unavailable') for call in calls):
                        context_issues.append('PER_CALL_PROMPT_PROVENANCE_UNAVAILABLE')
                    primary = [c for c in calls if isinstance(c, dict) and c.get('stage') == 'PRIMARY']
                    if len(primary) != 1 or primary[0].get('model') != row.get('model'):
                        context_issues.append('PRIMARY_MODEL_PROVENANCE_MISMATCH')
                report = evaluate({'cases': [case]}, {'results': [row]})
                reports.append(report)
                scores[repeat, ident] = report
                rows.append(row)
                raw[name, repeat, ident] = row
        if any(len(models) > 1 for models in model_by_type.values()):
            context_issues.append('MODEL_DRIFT_WITHIN_INPUT_TYPE')
        perf = summarize(rows, prices)
        # Keep private task/source text out of the benchmark summary.
        call_models = sorted({(str(call.get('stage')), str(call.get('provider')), str(call.get('model')))
                              for row in rows for call in row.get('aiCalls', []) if isinstance(call, dict)})
        scored[name] = dict(goldCoverage=dict(verifiedCases=sum(c.get('reviewStatus') == 'VERIFIED' for c in cases), totalCases=len(cases),
                                              unverifiedCaseIds=[c['id'] for c in cases if c.get('reviewStatus') != 'VERIFIED']), callModels=[dict(stage=stage, provider=provider, model=model) for stage, provider, model in call_models], models={kind: sorted(str(m) for m in models) for kind, models in model_by_type.items()},
                            qualityStatus='KEYWORD_PROXY' if any(r['verifiedCount'] for r in reports) else 'NO_VERIFIED_GOLD',
                            quality=quality(reports), performance=perf,
                            buckets={kind: summarize([r for r in rows if r['inputType'] == kind], prices) for kind in sorted({r['inputType'] for r in rows})},
                            contextIssues=sorted(set(context_issues)))
        per_case[name] = scores
    for name, result in scored.items():
        baseline_result = scored[baseline]
        issues = set(result['contextIssues']) | set(baseline_result['contextIssues'])
        regressions = []
        for repeat in range(next(iter(repeats))):
            if contexts[name, repeat] != contexts[baseline, repeat] or contexts[name, repeat] != contexts[name, 0]:
                issues.add('CONTROLLED_CONTEXT_CHANGED')
            for case in cases:
                ident = case['id']
                before, after = raw[baseline, repeat, ident], raw[name, repeat, ident]
                if before.get('success') and after.get('success'):
                    keys = ('promptVersion', 'ruleVersion', 'experienceVersion') if comparison_kind == 'MODEL' else ('model',)
                    if any(before.get(k) != after.get(k) for k in keys):
                        issues.add('COMPARISON_VARIABLES_CHANGED')
                    before_calls = {call.get('stage'): call for call in before.get('aiCalls', []) if isinstance(call, dict)}
                    after_calls = {call.get('stage'): call for call in after.get('aiCalls', []) if isinstance(call, dict)}
                    field = 'promptVersion' if comparison_kind == 'MODEL' else 'model'
                    if any(before_calls[stage].get(field) != after_calls[stage].get(field) for stage in before_calls.keys() & after_calls.keys()):
                        issues.add('PER_CALL_COMPARISON_VARIABLES_CHANGED')
                old, new = per_case[baseline][repeat, ident], per_case[name][repeat, ident]
                if not old['verifiedCount']:
                    continue
                a, b = old['total'], new['total']
                # No loss in one sample can be cancelled by gains in another.
                if (b['matched'] < a['matched'] or b['predicted']-b['matched'] > a['predicted']-a['matched']
                        or any(a[k] is not None and (b[k] is None or b[k] < a[k]) for k in METRICS)):
                    regressions.append(dict(caseId=ident, repeat=repeat))
        result['contextIssues'] = sorted(issues)
        result['qualityRegressions'] = regressions
        result['qualityGate'] = 'UNAVAILABLE' if result['goldCoverage']['unverifiedCaseIds'] else 'REGRESSED' if regressions else 'PASS'
        latency = [lower_gate(baseline_result['performance'], result['performance'], ('p50Ms', 'p95Ms', 'failureRate'))]
        for kind, before in baseline_result['buckets'].items():
            after = result['buckets'][kind]
            latency.append(lower_gate(before, after, ('p50Ms', 'p95Ms', 'failureRate')))
            if before['cacheBuckets']['HIT']['requests'] or after['cacheBuckets']['HIT']['requests']:
                latency.append(lower_gate(before['cacheBuckets']['MISS'], after['cacheBuckets']['MISS'], ('p50Ms', 'p95Ms', 'failureRate')))
        result['latencyGate'] = 'REGRESSED' if 'REGRESSED' in latency else 'UNAVAILABLE' if 'UNAVAILABLE' in latency else 'PASS'
        old, new = baseline_result['performance'], result['performance']
        costs = [cost_gate(old, new)]
        for kind, before in baseline_result['buckets'].items():
            after = result['buckets'][kind]
            costs.append(cost_gate(before, after))
            if before['cacheBuckets']['HIT']['requests'] or after['cacheBuckets']['HIT']['requests']:
                costs.append(cost_gate(before['cacheBuckets']['MISS'], after['cacheBuckets']['MISS']))
        result['costGate'] = 'REGRESSED' if 'REGRESSED' in costs else 'UNAVAILABLE' if 'UNAVAILABLE' in costs else 'PASS'
        result['deltas'] = {key: new[key]-old[key] if numeric(old.get(key)) and numeric(new.get(key)) else None
                            for key in ('p50Ms', 'p95Ms', 'averageCalls', 'averageTokensIn', 'averageTokensOut', 'averageConfiguredCost')}
        result['decision'] = ('BASELINE' if name == baseline else 'UNAVAILABLE' if issues or 'UNAVAILABLE' in (result['qualityGate'], result['latencyGate'], result['costGate'])
                              else 'REGRESSED' if 'REGRESSED' in (result['qualityGate'], result['latencyGate'], result['costGate']) else 'PROXY_NONREGRESSION_PASS')
    return dict(schemaVersion=1, fixtureHash=fixture_hash, comparisonKind=comparison_kind, baseline=baseline, variants=scored,
                warning='Keyword proxies and declared context are not independently verified semantic accuracy or controlled-network proof. Costs are configured-rate estimates, not bills. No automatic model switch.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', required=True, type=Path)
    parser.add_argument('--manifest', required=True, type=Path, help='baseline, comparisonKind, variants {id: [prediction paths]}')
    parser.add_argument('--prices', type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    manifest = read_json(args.manifest)
    variants = {name: [read_json(args.manifest.parent/path) for path in paths] for name, paths in manifest['variants'].items()}
    result = benchmark(read_json(args.fixtures), variants, manifest['baseline'], read_json(args.prices) if args.prices else None,
                       args.fixtures.parent, manifest.get('comparisonKind', 'MODEL'))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({name: {'decision': r['decision'], 'qualityGate': r['qualityGate'], 'latencyGate': r['latencyGate'], 'costGate': r['costGate']}
                      for name, r in result['variants'].items()}, ensure_ascii=False, indent=2))
    candidates = [r['decision'] for name, r in result['variants'].items() if name != result['baseline']]
    raise SystemExit(1 if 'REGRESSED' in candidates else 2 if 'UNAVAILABLE' in candidates else 0)


if __name__ == '__main__':
    main()
