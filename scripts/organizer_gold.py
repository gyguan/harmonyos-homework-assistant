"""Human annotation receipts, independent of inference and keyword scoring.
Receipts bind explicit attestations to the exact source bytes and task annotation.
They record a human declaration; they cannot establish the declaration's truth.
"""
from datetime import datetime, timezone
import re
from organizer_eval_inputs import case_fingerprint, digest

CHECKS = ('realTeacherSource', 'parentReviewed', 'privacyReviewed', 'teacherAttributionReviewed',
          'completeTaskSetReviewed', 'keyFieldsReviewed', 'sourceEvidenceReviewed')
FIELDS = ('subject', 'title', 'instruction', 'textbookRef', 'taskDate', 'expectedMinutes')


def annotation_digest(case):
    # Paths may move; image bytes are bound by inputFingerprint in the receipt.
    return digest({key: case.get(key) for key in ('id', 'teacherKey', 'sourceType', 'sourceText',
        'sourceLabel', 'teacherName', 'contentType', 'expected', 'provenance')})


def require(condition, code):
    if not condition:
        raise ValueError(code)


def validate_annotations(case):
    require(bool(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', case.get('id', ''))), 'INVALID_CASE_ID')
    require(bool(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', case.get('teacherKey', ''))), 'INVALID_TEACHER_KEY')
    require(case.get('sourceType') in ('TEXT', 'IMAGE'), 'INVALID_SOURCE_TYPE')
    tasks = case.get('expected')
    require(isinstance(tasks, list), 'MISSING_TASK_ANNOTATIONS')
    for task in tasks:
        require(isinstance(task, dict) and isinstance(task.get('keywords'), list)
                and bool(task['keywords']) and all(isinstance(v, str) and v.strip() for v in task['keywords']), 'MISSING_TASK_KEYWORDS')
        require(isinstance(task.get('subject'), str) and bool(task['subject'].strip()), 'MISSING_TASK_SUBJECT')
        require(isinstance(task.get('fields'), dict) and all(key in task['fields'] for key in FIELDS), 'INCOMPLETE_KEY_FIELDS')
        require(task['fields']['subject'] == task['subject'], 'INCONSISTENT_SUBJECT')
        require(all(isinstance(task['fields'][key], str) and bool(task['fields'][key].strip()) for key in FIELDS if key != 'expectedMinutes'), 'INVALID_KEY_FIELDS')
        require(type(task['fields']['expectedMinutes']) is int and 1 <= task['fields']['expectedMinutes'] <= 240, 'INVALID_EXPECTED_MINUTES')
        try:
            datetime.strptime(task['fields']['taskDate'], '%Y-%m-%d')
        except (ValueError, TypeError):
            raise ValueError('INVALID_TASK_DATE') from None
        spans = task.get('sourceEvidenceTexts')
        require(isinstance(spans, list) and bool(spans) and all(isinstance(v, str) and v.strip() for v in spans), 'MISSING_SOURCE_EVIDENCE')
        if case['sourceType'] == 'TEXT':
            require(all(span in case.get('sourceText', '') for span in spans), 'EVIDENCE_OUTSIDE_SOURCE')


def validate_declaration(declaration):
    require(isinstance(declaration, dict) and all(declaration.get(key) is True for key in CHECKS), 'INCOMPLETE_HUMAN_REVIEW')
    require(bool(re.fullmatch(r'[A-Za-z0-9_-]{1,80}', declaration.get('reviewerKey', ''))), 'INVALID_REVIEWER_KEY')
    require(isinstance(declaration.get('reviewedAt'), str), 'INVALID_REVIEW_DATE')
    try:
        at = datetime.fromisoformat(declaration['reviewedAt'].replace('Z', '+00:00'))
        require(at.tzinfo is not None and at <= datetime.now(timezone.utc), 'INVALID_REVIEW_DATE')
    except (ValueError, TypeError):
        raise ValueError('INVALID_REVIEW_DATE') from None


def verify_case(case, declaration, root):
    require(case.get('reviewStatus') == 'DRAFT', 'ONLY_DRAFT_CAN_BE_VERIFIED')
    validate_annotations(case)
    validate_declaration(declaration)
    require(declaration.get('annotationDigest') == annotation_digest(case), 'STALE_ANNOTATION_REVIEW')
    fingerprint = case_fingerprint(case, root)
    # Explicit input digest also prevents replacing an image between inspection and signing.
    require(declaration.get('inputFingerprint') == fingerprint, 'STALE_SOURCE_REVIEW')
    return {**case, 'reviewStatus': 'VERIFIED', 'verification': {
        **declaration, 'method': 'HUMAN_DECLARATION_V1', 'inputFingerprint': fingerprint}}


def validate_receipt(case, prediction=None, root=None):
    receipt = case.get('verification')
    if receipt is None:
        require(case.get('provenance', {}).get('kind') != 'EXISTING_PRIVATE_BATCH', 'MANAGED_GOLD_REQUIRES_RECEIPT')
        return  # Existing manually curated fixtures remain compatible.
    require(isinstance(receipt, dict) and case.get('reviewStatus') == 'VERIFIED' and receipt.get('method') == 'HUMAN_DECLARATION_V1', 'INVALID_VERIFICATION_RECEIPT')
    validate_annotations(case)
    validate_declaration(receipt)
    require(receipt.get('annotationDigest') == annotation_digest(case), 'VERIFIED_ANNOTATION_CHANGED')
    if root is not None:
        require(receipt.get('inputFingerprint') == case_fingerprint(case, root), 'VERIFIED_SOURCE_CHANGED')
    if prediction is not None:
        require(receipt.get('inputFingerprint') == prediction.get('inputFingerprint'), 'PREDICTION_SOURCE_MISMATCH')
