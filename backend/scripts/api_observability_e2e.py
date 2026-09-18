#!/usr/bin/env python3
from __future__ import annotations

import sys
import time

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        first_id = "e2e-observe-1"
        second_id = "e2e-observe-2"
        common = {
            "X-Client-Scene": "e2e.duplicate",
            "X-Client-Request-Key": "GET%7C%2Fapi%2Fv1%2Fhealth",
        }

        first = expect(
            http(base_url, "GET", "/api/v1/health",
                 extra_headers={**common, "X-Request-Id": first_id}),
            (200,), "observability first request",
        )
        require(first.headers.get("X-Request-Id") == first_id,
                "backend did not echo the first X-Request-Id")

        second = expect(
            http(base_url, "GET", "/api/v1/health",
                 extra_headers={**common, "X-Request-Id": second_id}),
            (200,), "observability duplicate request",
        )
        require(second.headers.get("X-Request-Id") == second_id,
                "backend did not echo the second X-Request-Id")

        time.sleep(0.5)
        print("API_OBSERVABILITY_E2E_PASS")
        return 0
    except SmokeFailure as exc:
        print(f"API_OBSERVABILITY_E2E_FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
