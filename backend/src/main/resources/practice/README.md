# Practice preset content

Built-in Practice content is split by **grade × subject** under:

`backend/src/main/resources/practice/preset/`

The manifest is the entry point:

`preset/manifest.json`

It declares exactly one JSON shard for every supported grade and required subject, for example:

```text
preset/
  manifest.json
  G1/
    CHINESE.json
    MATH.json
    ENGLISH.json
  G2/
    CHINESE.json
    MATH.json
    ENGLISH.json
  ...
  G6/
    CHINESE.json
    MATH.json
    ENGLISH.json
```

Each shard owns all PRESET papers for that grade and subject. Do not recreate a monolithic
`preset-catalog.json`.

## Audience metadata

Every Paper declares:

- `grade`: `G1` ... `G6`
- `subject`: `CHINESE` / `MATH` / `ENGLISH`
- `semester`: `ALL` / `S1` / `S2`

`ALL` means a stable grade-level foundation paper that can be used in either semester.
`S1` and `S2` are semester-specific.

The client defaults from the active student's `grade + semester`. The backend independently
enforces the same audience rule when a fresh PracticeAttempt is created, so a client or API caller
cannot start a paper from the wrong grade or semester.

Historical repeat / wrong-only attempts remain bound to their original Paper version and are not
blocked if the student later advances to another grade.

## Content workflow

1. Edit the matching grade/subject shard, such as `preset/G2/MATH.json`.
2. Add a **new paper ID or a new immutable version**.
3. Keep published versions immutable. If a released question, answer, explanation, audience, or
   other semantic content changes, increment `version` instead of overwriting history.
4. Regenerate client metadata:
   `python scripts/generate_practice_catalog.py`
5. Run the content gate:
   `python scripts/validate_practice_content.py`
6. Commit the shard and generated `PresetPracticeCatalog.ets` together.

The backend loads `manifest.json`, merges every shard, validates the merged catalog, and imports
missing immutable Paper versions into PostgreSQL.

## G2 first-semester baseline

The active demo/student profile is currently **二年级上学期**. G2/S1 therefore has deeper coverage
than other grades.

Current semester-specific coverage includes:

- Chinese: words and phrases, quantifiers, sentence order, punctuation, simple sentence patterns,
  original short reading passages, information extraction, simple inference, and review.
- Math: addition/subtraction within 100, chained operations, shopping/RMB, multiplication meaning,
  2–5 and 6–9 multiplication facts, centimetres/metres, equal sharing/basic division, one-step
  applications, and review.
- English: greetings, self-introduction, classmates, numbers/colors, family, simple `can`,
  basic appearance words, rooms/kitchen, `in/on`, nature/place vocabulary, and review.

These are original Practice questions. They are not copied textbook exercises.

The quality gate also contains explicit G2/S1 scope checks and rejects clearly advanced content
such as decimals, fractions, equations, area/volume topics, or advanced English grammar.

## Quality rules

The gate validates:

- manifest contains exactly 18 grade/subject shard files
- shard path, declared grade/subject, and every Paper agree
- globally unique question IDs
- unique `paperId + version`
- legal grade / subject / semester / difficulty / question type
- contiguous question order and declared question count
- non-empty explanations, hints, and tags
- no duplicate stems inside one paper
- choice answers reference declared options
- numeric answers are parseable
- G1–G6 baseline Starter + Core coverage for Chinese, Math, and English
- enhanced G2/S1 paper and question minimums
- G2/S1 age/semester scope guardrails
- generated client metadata stays synchronized with all shards
- fresh Attempt creation is protected by the backend grade/semester audience policy

## AI-generated extension

The domain already reserves `sourceType = AI_GENERATED`.

Future AI paper generation should produce the same `PracticeContentCatalog.Paper` contract and
call `PracticeContentValidator.validatePaper(...)` before publication. AI-generated content must
declare `grade`, `subject`, and `semester`, pass the same quality rules, and be persisted as a
new immutable Paper version.

Do not create a second AI-only question model and do not bypass the validator or audience policy.
