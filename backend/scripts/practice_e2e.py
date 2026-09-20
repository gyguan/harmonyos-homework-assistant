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

        history_before = expect(
            http(base_url, "GET", f"/api/v1/students/{student_id}/practice/attempts?paperId={paper_id}", token=token),
            (200,),
            "list practice history by paper",
        ).json()
        source_summary = next((item for item in history_before if item.get("id") == attempt_id), None)
        require(source_summary is not None, "submitted attempt missing from practice history")
        require(source_summary.get("status") == "SUBMITTED", "history did not preserve submitted status")
        source_attempt_no = int(source_summary.get("attemptNo", 0))

        repeated = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{attempt_id}/repeat", token=token),
            (200,),
            "repeat submitted practice attempt",
        ).json()
        repeated_id = repeated["id"]
        require(repeated_id != attempt_id, "repeat must create a new immutable practice instance")
        require(repeated.get("sourceAttemptId") == attempt_id, "repeat did not preserve sourceAttemptId lineage")
        require(int(repeated.get("attemptNo", 0)) == source_attempt_no + 1,
                "repeat attemptNo must advance without overwriting history")
        require([item.get("id") for item in repeated.get("questions", [])] ==
                [item.get("id") for item in questions],
                "repeat must freeze the exact source question set")

        previous = repeated.get("previousAnswers") or []
        previous_first = next((item for item in previous if item.get("questionId") == first_id), None)
        require(previous_first is not None and previous_first.get("answerValue") == "30",
                "repeat did not expose the student's previous answer")
        require(previous_first.get("correct") is True,
                "repeat previous answer must preserve previous correctness")
        require((repeated.get("answers") or []) == [],
                "new repeat attempt must start with an empty current answer set")

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{repeated_id}/answers/{first_id}",
                token=token,
                payload={"answerValue": "31"},
            ),
            (200,),
            "save independent answer in repeated attempt",
        )
        repeated_result = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{repeated_id}/submit", token=token),
            (200,),
            "submit repeated practice attempt",
        ).json()
        require(int(repeated_result.get("score", -1)) == 0,
                "repeated attempt must be judged independently from the source attempt")

        source_result_again = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}/result", token=token),
            (200,),
            "reload source result after repeat",
        ).json()
        require(int(source_result_again.get("score", -1)) == 1,
                "repeating practice must never mutate the source result")

        history_after = expect(
            http(base_url, "GET", f"/api/v1/students/{student_id}/practice/attempts", token=token),
            (200,),
            "list all practice history",
        ).json()
        history_ids = [item.get("id") for item in history_after]
        require(attempt_id in history_ids and repeated_id in history_ids,
                "history must retain source and repeated attempts as separate instances")

        expect(
            http(base_url, "DELETE", f"/api/v1/students/{student_id}", token=token),
            (409,),
            "student deletion rejects persisted practice history",
        )

        print(
            f"PRACTICE_E2E_PASS source={attempt_id} repeat={repeated_id} "
            f"sourceScore={result['score']}/{result['maxScore']} repeatScore={repeated_result['score']}/{repeated_result['maxScore']}"
        )
        return 0
    except SmokeFailure as exc:
        print(f"PRACTICE_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"PRACTICE_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
