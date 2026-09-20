#!/usr/bin/env python3
from __future__ import annotations

import sys

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(
            http(base_url, "POST", "/api/v1/auth/login",
                 payload={"loginName": "parent", "password": "parent123"}),
            (200,),
            "practice e2e login",
        ).json()
        token = login["token"]
        student_id = "student-xiaoyu-001"
        paper_id = "MATH-G3-STARTER-001"

        paper = expect(
            http(base_url, "GET", f"/api/v1/practice/papers/{paper_id}?version=1", token=token),
            (200,),
            "load practice paper",
        ).json()
        require(paper.get("id") == paper_id, "practice paper id mismatch")
        require(int(paper.get("questionCount", 0)) == 10, "practice paper must expose 10 starter questions")
        require(paper.get("sourceType") == "PRESET", "starter practice paper must be PRESET")

        attempt = expect(
            http(
                base_url,
                "POST",
                f"/api/v1/students/{student_id}/practice/attempts",
                token=token,
                payload={"paperId": paper_id, "paperVersion": 1},
            ),
            (200,),
            "start practice attempt",
        ).json()
        attempt_id = attempt["id"]
        questions = attempt.get("questions") or []
        require(len(questions) == 10, "practice attempt did not freeze all paper questions")
        require(attempt.get("status") == "IN_PROGRESS", "new practice attempt must be IN_PROGRESS")
        require(int(attempt.get("attemptNo", 0)) >= 1, "practice attemptNo missing")
        require(all("answerSpec" not in item and "explanation" not in item for item in questions),
                "practice attempt leaked answer or explanation before submission")

        first_id = questions[0]["id"]
        second_id = questions[1]["id"]
        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/answers/{first_id}",
                token=token,
                payload={"answerValue": "30"},
            ),
            (200,),
            "save correct practice answer",
        )
        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/answers/{second_id}",
                token=token,
                payload={"answerValue": "999"},
            ),
            (200,),
            "save wrong practice answer",
        )

        reloaded = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}", token=token),
            (200,),
            "reload practice attempt",
        ).json()
        require(int(reloaded.get("answeredCount", 0)) == 2, "saved practice answers were not persisted")

        result = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{attempt_id}/submit", token=token),
            (200,),
            "submit practice attempt",
        ).json()
        require(int(result.get("maxScore", 0)) == 10, "practice result max score mismatch")
        require(int(result.get("score", -1)) == 1, "deterministic practice score mismatch")
        require(int(result.get("correctCount", -1)) == 1, "practice correct count mismatch")
        require(int(result.get("wrongCount", -1)) == 9, "wrong count must include wrong and unanswered questions")

        results = result.get("questions") or []
        require(len(results) == 10, "practice result missing question review")
        require(results[0].get("correct") is True and results[0].get("correctAnswer") == "30",
                "correct numeric question was not judged correctly")
        require(results[1].get("correct") is False, "wrong numeric question was not judged incorrectly")

        loaded_result = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}/result", token=token),
            (200,),
            "reload submitted practice result",
        ).json()
        require(loaded_result.get("attemptId") == attempt_id, "practice result was not persisted")

        submitted = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}", token=token),
            (200,),
            "reload submitted practice attempt",
        ).json()
        require(submitted.get("status") == "SUBMITTED", "submitted attempt status was not persisted")

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/answers/{first_id}",
                token=token,
                payload={"answerValue": "31"},
            ),
            (409,),
            "reject answer mutation after practice submission",
        )

        print(f"PRACTICE_E2E_PASS attemptId={attempt_id} score={result['score']}/{result['maxScore']}")
        return 0
    except SmokeFailure as exc:
        print(f"PRACTICE_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"PRACTICE_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
