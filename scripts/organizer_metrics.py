"""Content-free organizer latency/usage report helpers. Standard library only."""
import math
from statistics import mean


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0


def percentile(values, fraction):
    ordered = sorted(v for v in values if numeric(v))
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)] if ordered else None


def summarize(rows, prices=None):
    """Unavailable provider usage stays missing; partial sums aren't presented as totals."""
    def avg(key):
        values = [r[key] for r in rows if numeric(r.get(key))]
        return mean(values) if values else None
    usage = [r for r in rows if numeric(r.get('tokensIn')) and numeric(r.get('tokensOut'))]
    costs = []
    for row in usage:
        rate = (prices or {}).get(row.get('model'))
        if rate:
            costs.append((row['tokensIn'] * rate['inputPerMillion'] +
                          row['tokensOut'] * rate['outputPerMillion']) / 1_000_000)
    stages = sorted({k for row in rows for k in row.get('stagesMs', {})})
    return {
        'requests': len(rows),
        'failureRate': mean(not r.get('success', True) for r in rows) if rows else None,
        'p50Ms': percentile([r.get('elapsedMs') for r in rows], .5),
        'p95Ms': percentile([r.get('elapsedMs') for r in rows], .95),
        'reviewRate': mean(bool(r.get('reviewTriggered')) for r in rows) if rows else None,
        'averageCalls': avg('callCount'),
        'averageTokensIn': avg('tokensIn'), 'averageTokensOut': avg('tokensOut'),
        'usageAvailableRequests': len(usage), 'usageUnavailableRequests': len(rows) - len(usage),
        'averageConfiguredCost': mean(costs) if costs else None,
        'costAvailableRequests': len(costs),
        'costNote': 'Configured price estimate, not a provider bill; cached/image pricing may differ.',
        'stages': {key: {'p50Ms': percentile([r.get('stagesMs', {}).get(key) for r in rows], .5),
                         'p95Ms': percentile([r.get('stagesMs', {}).get(key) for r in rows], .95)}
                   for key in stages},
    }
