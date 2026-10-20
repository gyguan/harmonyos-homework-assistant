"""Content-free organizer latency/usage report helpers. Standard library only."""
import math
from statistics import mean


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0


def percentile(values, fraction):
    ordered = sorted(v for v in values if numeric(v))
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)] if ordered else None


def configured_cost(row, prices):
    """Configured rates times actual usage; missing per-call usage/rates stays unavailable.

    aiCalls takes precedence over aggregate primary-model metadata, so a differently priced
    review model is never charged at the primary model's rate. Currency is never converted.
    """
    if row.get('cacheHit') is True and row.get('callCount') == 0:
        return 0.0, None
    calls = row.get('aiCalls')
    if calls is not None:
        if not isinstance(calls, list) or not calls or row.get('callCount') != len(calls):
            return None, None
    else:
        calls = [dict(model=row.get('model'), provider=row.get('provider'), usage=dict(
            tokensIn=row.get('tokensIn'), tokensOut=row.get('tokensOut'), cachedTokens=row.get('cachedTokensIn')))]
    cost, currencies = 0.0, set()
    for call in calls:
        if not isinstance(call, dict) or not isinstance(call.get('usage', {}), dict):
            return None, None
        key = str(call.get('provider')) + '/' + str(call.get('model'))
        rate = (prices or {}).get(key, (prices or {}).get(call.get('model')))
        usage = call.get('usage') or {}
        if not isinstance(rate, dict) or not all(numeric(rate.get(k)) for k in ('inputPerMillion', 'outputPerMillion')):
            return None, None
        if not all(numeric(usage.get(k)) for k in ('tokensIn', 'tokensOut')):
            return None, None
        currency = rate.get('currency', 'UNSPECIFIED')
        if not isinstance(currency, str):
            return None, None
        currencies.add(currency)
        tokens, output, cached = usage['tokensIn'], usage['tokensOut'], usage.get('cachedTokens')
        if 'cachedInputPerMillion' in rate:
            if not numeric(rate['cachedInputPerMillion']) or not numeric(cached) or cached > tokens:
                return None, None
            cost += ((tokens-cached)*rate['inputPerMillion']+cached*rate['cachedInputPerMillion']+output*rate['outputPerMillion'])/1_000_000
        else:
            cost += (tokens*rate['inputPerMillion']+output*rate['outputPerMillion'])/1_000_000
    return (cost, next(iter(currencies))) if len(currencies) == 1 else (None, None)


def summarize(rows, prices=None, *, include_cache_buckets=True):
    """Unavailable provider usage stays missing; partial sums aren't presented as totals."""
    def avg(key):
        values = [r[key] for r in rows if numeric(r.get(key))]
        return mean(values) if values else None
    usage = [r for r in rows if numeric(r.get('tokensIn')) and numeric(r.get('tokensOut'))]
    priced = [configured_cost(row, prices) for row in rows]
    currencies = {currency for cost, currency in priced if cost is not None and currency is not None}
    # Never average different currencies. Zero-inference cache hits contribute known zero cost.
    costs = [cost for cost, _ in priced if cost is not None] if len(currencies) <= 1 else []
    stages = sorted({k for row in rows for k in row.get('stagesMs', {})})
    result = {
        'requests': len(rows),
        'failureRate': mean(not r.get('success', True) for r in rows) if rows else None,
        'p50Ms': percentile([r.get('elapsedMs') for r in rows], .5),
        'p95Ms': percentile([r.get('elapsedMs') for r in rows], .95),
        'cacheHitRate': mean(bool(r.get('cacheHit')) for r in rows) if rows else None,
        'reviewRate': mean(bool(r.get('reviewTriggered')) for r in rows) if rows else None,
        'averageCalls': avg('callCount'),
        'averageTokensIn': avg('tokensIn'), 'averageTokensOut': avg('tokensOut'),
        'averageCachedTokensIn': avg('cachedTokensIn'), 'averageImageTokensIn': avg('imageTokensIn'),
        'usageAvailableRequests': len(usage), 'usageUnavailableRequests': len(rows) - len(usage),
        'averageConfiguredCost': mean(costs) if costs else None,
        'costAvailableRequests': len(costs), 'costUnavailableRequests': len(rows)-len(costs),
        'costCurrency': next(iter(currencies)) if len(currencies) == 1 else None,
        'costNote': 'Configured-rate estimate from actual usage, not a provider bill; no currency conversion. Cached discount applies only when supplied; otherwise full input rate.',
        'stages': {key: {'p50Ms': percentile([r.get('stagesMs', {}).get(key) for r in rows], .5),
                         'p95Ms': percentile([r.get('stagesMs', {}).get(key) for r in rows], .95)}
                   for key in stages},
    }

    if include_cache_buckets:
        # A warm response must not hide a regression in uncached model inference.
        result['cacheBuckets'] = {
            'HIT': summarize([r for r in rows if r.get('cacheHit') is True], prices, include_cache_buckets=False),
            'MISS': summarize([r for r in rows if r.get('cacheHit') is False], prices, include_cache_buckets=False),
            'UNKNOWN': summarize([r for r in rows if not isinstance(r.get('cacheHit'), bool)], prices, include_cache_buckets=False),
        }
    return result
