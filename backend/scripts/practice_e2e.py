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
        paper_id = "MATH-G2-S1-SYNC-ADD-SUB-001"

        paper = expect(
            http(base_url, "GET", f"/api/v1/practice/papers/{paper_id}?version=2", token=token),
            (200,),
            "load textbook-sync practice paper",
        ).json()
        require(paper.get("id") == paper_id, "practice paper id mismatch")
        require(int(paper.get("questionCount", 0)) == 12,
                "rebuilt practice paper must expose 12 questions")
        require(paper.get("sourceType") == "PRESET", "rebuilt practice paper must be PRESET")
        require(paper.get("semester") == "S1", "rebuilt practice paper must target first semester")
        require(paper.get("track") == "TEXTBOOK_SYNC",
                "textbook-sync paper must expose TEXTBOOK_SYNC")

        extra_paper_id = "MATH-G2-S1-EXTRA-LIFE-001"
        extra_paper = expect(
            http(base_url, "GET", f"/api/v1/practice/papers/{extra_paper_id}?version=2", token=token),
            (200,),
            "load extracurricular practice paper",
        ).json()
        require(extra_paper.get("track") == "EXTRACURRICULAR",
                "extracurricular paper must expose EXTRACURRICULAR")
        require(int(extra_paper.get("questionCount", 0)) == 12,
                "extracurricular paper must expose 12 questions")

        expect(
            http(base_url, "GET", "/api/v1/practice/papers/MATH-G2-STARTER-001?version=1", token=token),
            (404,),
            "retired practice paper must be unavailable",
        )

        attempt = expect(
            http(
                base_url,
                "POST",
                f"/api/v1/students/{student_id}/practice/attempts",
                token=token,
                payload={"paperId": paper_id, "paperVersion": 2},
            ),
            (200,),
            "start practice attempt",
        ).json()
        attempt_id = attempt["id"]
        questions = attempt.get("questions") or []
        require(len(questions) == 12, "practice attempt did not freeze all paper questions")
        require(attempt.get("status") == "IN_PROGRESS", "new practice attempt must be IN_PROGRESS")
        require(attempt.get("mode") == "FULL", "new practice attempt must start in FULL mode")
        require(int(attempt.get("attemptNo", 0)) >= 1, "practice attemptNo missing")
        require(all("answerSpec" not in item and "explanation" not in item for item in questions),
                "practice attempt leaked answer or explanation before submission")

        first_id = questions[0]["id"]
        second_id = questions[1]["id"]
        third_id = questions[2]["id"]

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/answers/{first_id}",
                token=token,
                payload={"answerValue": "65"},
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

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{first_id}",
                token=token,
                payload={"content": "先看清十位和个位"},
            ),
            (200,),
            "create first practice note",
        )
        updated_note = expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{first_id}",
                token=token,
                payload={"content": "37加28等于65，先对齐数位"},
            ),
            (200,),
            "update first practice note",
        ).json()
        require(updated_note.get("content") == "37加28等于65，先对齐数位",
                "practice note update was not persisted")

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{second_id}",
                token=token,
                payload={"content": "第二题要注意两个加数"},
            ),
            (200,),
            "save note on wrong question",
        )
        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{third_id}",
                token=token,
                payload={"content": "临时笔记"},
            ),
            (200,),
            "save temporary practice note",
        )
        expect(
            http(
                base_url,
                "DELETE",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{third_id}",
                token=token,
            ),
            (200, 204),
            "delete temporary practice note",
        )

        reloaded = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}", token=token),
            (200,),
            "reload practice attempt",
        ).json()
        require(int(reloaded.get("answeredCount", 0)) == 2, "saved practice answers were not persisted")
        require(int(reloaded.get("noteCount", 0)) == 2, "practice note count mismatch before submission")
        notes = reloaded.get("notes") or []
        require(any(item.get("questionId") == first_id and
                    item.get("content") == "37加28等于65，先对齐数位" for item in notes),
                "updated first practice note missing")
        require(any(item.get("questionId") == second_id for item in notes),
                "wrong-question note missing")
        require(not any(item.get("questionId") == third_id for item in notes),
                "deleted practice note still present")

        result = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{attempt_id}/submit", token=token),
            (200,),
            "submit practice attempt",
        ).json()
        require(result.get("mode") == "FULL", "submitted source attempt mode mismatch")
        require(int(result.get("maxScore", 0)) == 12, "practice result max score mismatch")
        require(int(result.get("score", -1)) == 1, "deterministic practice score mismatch")
        require(int(result.get("correctCount", -1)) == 1, "practice correct count mismatch")
        require(int(result.get("wrongCount", -1)) == 11, "wrong count must include wrong and unanswered questions")
        require(int(result.get("noteCount", 0)) == 2, "submitted practice note count mismatch")

        results = result.get("questions") or []
        require(len(results) == 12, "practice result missing question review")
        require(results[0].get("correct") is True and results[0].get("correctAnswer") == "65",
                "correct numeric question was not judged correctly")
        require(results[0].get("noteContent") == "37加28等于65，先对齐数位",
                "result did not preserve first question note")
        require(results[1].get("correct") is False, "wrong numeric question was not judged incorrectly")
        require(results[1].get("noteContent") == "第二题要注意两个加数",
                "result did not preserve wrong-question note")

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
                payload={"answerValue": "11"},
            ),
            (409,),
            "reject answer mutation after practice submission",
        )
        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{first_id}",
                token=token,
                payload={"content": "不能改历史笔记"},
            ),
            (409,),
            "reject note mutation after practice submission",
        )
        expect(
            http(
                base_url,
                "DELETE",
                f"/api/v1/practice/attempts/{attempt_id}/notes/{second_id}",
                token=token,
            ),
            (409,),
            "reject note deletion after practice submission",
        )

        history_before = expect(
            http(base_url, "GET", f"/api/v1/students/{student_id}/practice/attempts?paperId={paper_id}", token=token),
            (200,),
            "list practice history by paper",
        ).json()
        source_summary = next((item for item in history_before if item.get("id") == attempt_id), None)
        require(source_summary is not None, "submitted attempt missing from practice history")
        require(source_summary.get("status") == "SUBMITTED", "history did not preserve submitted status")
        require(int(source_summary.get("noteCount", 0)) == 2, "history did not preserve note count")
        source_attempt_no = int(source_summary.get("attemptNo", 0))

        repeated = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{attempt_id}/repeat", token=token),
            (200,),
            "repeat submitted practice attempt",
        ).json()
        repeated_id = repeated["id"]
        require(repeated_id != attempt_id, "repeat must create a new immutable practice instance")
        require(repeated.get("sourceAttemptId") == attempt_id, "repeat did not preserve sourceAttemptId lineage")
        require(repeated.get("mode") == "FULL", "full repeat mode mismatch")
        require(int(repeated.get("attemptNo", 0)) == source_attempt_no + 1,
                "repeat attemptNo must advance without overwriting history")
        require([item.get("id") for item in repeated.get("questions", [])] ==
                [item.get("id") for item in questions],
                "repeat must freeze the exact source question set")

        previous = repeated.get("previousAnswers") or []
        previous_first = next((item for item in previous if item.get("questionId") == first_id), None)
        require(previous_first is not None and previous_first.get("answerValue") == "65",
                "repeat did not expose the student's previous answer")
        require(previous_first.get("correct") is True,
                "repeat previous answer must preserve previous correctness")
        previous_notes = repeated.get("previousNotes") or []
        require(any(item.get("questionId") == first_id and
                    item.get("content") == "37加28等于65，先对齐数位" for item in previous_notes),
                "repeat did not expose the source note")
        require((repeated.get("answers") or []) == [],
                "new repeat attempt must start with an empty current answer set")
        require((repeated.get("notes") or []) == [],
                "new repeat attempt must not copy source notes into current notes")

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

        wrong_only = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{attempt_id}/wrong-only", token=token),
            (200,),
            "create wrong-only practice attempt",
        ).json()
        wrong_only_id = wrong_only["id"]
        require(wrong_only.get("mode") == "WRONG_ONLY", "wrong-only attempt mode mismatch")
        require(wrong_only.get("sourceAttemptId") == attempt_id,
                "wrong-only attempt did not preserve source lineage")
        wrong_questions = wrong_only.get("questions") or []
        wrong_ids = [item.get("id") for item in wrong_questions]
        require(len(wrong_ids) == 11, "wrong-only attempt must contain source wrong and unanswered questions")
        require(first_id not in wrong_ids, "wrong-only attempt must exclude source correct questions")
        require(second_id in wrong_ids, "wrong-only attempt must include source wrong questions")
        require((wrong_only.get("answers") or []) == [],
                "wrong-only attempt must start with empty current answers")
        require((wrong_only.get("notes") or []) == [],
                "wrong-only attempt must start with empty current notes")
        wrong_previous_notes = wrong_only.get("previousNotes") or []
        require(any(item.get("questionId") == second_id and
                    item.get("content") == "第二题要注意两个加数" for item in wrong_previous_notes),
                "wrong-only attempt must expose source note for included wrong question")
        require(not any(item.get("questionId") == first_id for item in wrong_previous_notes),
                "wrong-only attempt must not expose source notes for excluded correct questions")

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{wrong_only_id}/answers/{second_id}",
                token=token,
                payload={"answerValue": "35"},
            ),
            (200,),
            "save corrected wrong-only answer",
        )
        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/practice/attempts/{wrong_only_id}/notes/{second_id}",
                token=token,
                payload={"content": "专项重练后已经掌握"},
            ),
            (200,),
            "save independent wrong-only note",
        )
        wrong_result = expect(
            http(base_url, "POST", f"/api/v1/practice/attempts/{wrong_only_id}/submit", token=token),
            (200,),
            "submit wrong-only practice attempt",
        ).json()
        require(wrong_result.get("mode") == "WRONG_ONLY", "wrong-only result mode mismatch")
        require(int(wrong_result.get("maxScore", 0)) == 11, "wrong-only result max score mismatch")
        require(int(wrong_result.get("score", -1)) == 1, "wrong-only corrected answer score mismatch")
        require(int(wrong_result.get("noteCount", 0)) == 1, "wrong-only note count mismatch")

        source_result_again = expect(
            http(base_url, "GET", f"/api/v1/practice/attempts/{attempt_id}/result", token=token),
            (200,),
            "reload source result after repeat",
        ).json()
        require(int(source_result_again.get("score", -1)) == 1,
                "repeating practice must never mutate the source result")
        require(int(source_result_again.get("noteCount", 0)) == 2,
                "wrong-only practice must never mutate source notes")

        history_after = expect(
            http(base_url, "GET", f"/api/v1/students/{student_id}/practice/attempts", token=token),
            (200,),
            "list all practice history",
        ).json()
        history_ids = [item.get("id") for item in history_after]
        require(attempt_id in history_ids and repeated_id in history_ids and wrong_only_id in history_ids,
                "history must retain source, full-repeat and wrong-only attempts as separate instances")

        expect(
            http(base_url, "DELETE", f"/api/v1/students/{student_id}", token=token),
            (409,),
            "student deletion rejects persisted practice history",
        )

        print(
            f"PRACTICE_E2E_PASS source={attempt_id} repeat={repeated_id} wrongOnly={wrong_only_id} "
            f"sourceScore={result['score']}/{result['maxScore']} "
            f"repeatScore={repeated_result['score']}/{repeated_result['maxScore']} "
            f"wrongScore={wrong_result['score']}/{wrong_result['maxScore']}"
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
