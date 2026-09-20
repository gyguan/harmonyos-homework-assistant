# Practice preset content V2

The active built-in Practice catalog is intentionally scoped to the current product baseline:

- Region: Shenzhen
- Grade: G2 / 二年级
- Semester: S1 / 上学期
- Subjects: Chinese / Math / English
- Catalog types: TEXTBOOK_SYNC / EXTRACURRICULAR
- Content form: text-only, life-like scenarios; no Practice image assets

The manifest is the only catalog entry point:

`backend/src/main/resources/practice/preset/manifest.json`

It declares exactly six shards:

```text
preset/
  manifest.json
  G2/
    CHINESE_SYNC.json
    CHINESE_EXTRA.json
    MATH_SYNC.json
    MATH_EXTRA.json
    ENGLISH_SYNC.json
    ENGLISH_EXTRA.json
```

Current active baseline:

- 27 papers
- 324 questions
- each subject: 6 TEXTBOOK_SYNC papers + 3 EXTRACURRICULAR papers
- each paper: 12 questions

## Catalog type

Every active Paper declares:

- `grade = G2`
- `semester = S1`
- `subject = CHINESE | MATH | ENGLISH`
- `track = TEXTBOOK_SYNC | EXTRACURRICULAR`

`TEXTBOOK_SYNC` follows the G2 first-semester learning progression and core ability scope.
`EXTRACURRICULAR` stays age-appropriate but emphasizes reading, daily-life application,
language use, patterns, logic, science and Shenzhen-life contexts.

The App exposes the catalog type as a first-class filter:

`全部 / 教材同步 / 课外拓展`

The default filter is `教材同步`.

## Content positioning

The questions are original and do not copy commercial exercise books or textbook exercises.

The content uses familiar situations so a G2 student can understand the question without an image,
for example:

- school routines, class duty, PE, reading corners and sports day
- family organization, meals and weekend activities
- community libraries, parks, metro travel and local community activities
- simple Shenzhen contexts such as rainy weather, parks and public transport

A question must remain fully answerable from its text. Do not add stems such as
`看图`, `图中`, `图片` or `画面` unless a future product version explicitly restores
an audited visual-question contract.

## Subject baseline

### Chinese

TEXTBOOK_SYNC:
- words, quantifiers, synonyms/antonyms and vocabulary understanding
- sentence order, punctuation, simple 把/被 sentences
- original life and nature reading
- complete-sentence and situational expression
- stage review

EXTRACURRICULAR:
- Shenzhen life reading
- child-friendly science reading
- story comprehension and simple reasoning

### Math

TEXTBOOK_SYNC:
- addition/subtraction within 100
- centimetres/metres and simple measurement
- meaning of multiplication
- multiplication facts in life situations
- equal sharing and basic division
- intuitive symmetry/translation/rotation and multiplication/division application

EXTRACURRICULAR:
- daily-life math
- number/pattern discovery and simple equivalence
- queue/order/position logic and basic geometry thinking

The quality gate rejects clearly advanced content such as decimals, fractions, equations,
volume, percentages and other out-of-scope topics.

### English

TEXTBOOK_SYNC:
- greetings, names, numbers and colours
- family and basic appearance
- simple `can` + actions
- room vocabulary and `in/on`
- places and natural-world vocabulary
- stage review

EXTRACURRICULAR:
- school daily English
- Shenzhen-life situations
- very short reading passages

## Immutable history and retiring old catalogs

Source JSON is the active catalog, but PostgreSQL also contains historical Practice data.

When the active catalog changes:

1. new active PRESET papers are imported;
2. old PRESET papers that are no longer in the manifest are marked `ARCHIVED`;
3. their questions are retained in PostgreSQL;
4. historical Attempt / Result / repeat / wrong-only records remain traceable.

Do **not** physically delete historical paper/question rows that may already be referenced by an
Attempt. “Delete the old question bank” means remove it from the active catalog and archive its
persisted PRESET versions, not break immutable learning history.

## Content workflow

1. Edit the correct typed shard, for example `G2/MATH_SYNC.json`.
2. Use a new paper ID, or increment a released paper's immutable `version`.
3. Run:
   `python scripts/generate_practice_catalog.py`
4. Run:
   `python scripts/validate_practice_content.py`
5. Commit the JSON shard and generated `PresetPracticeCatalog.ets` together.
6. Run backend tests and the real PostgreSQL Practice E2E.

Do not recreate the old G1-G6 Starter/Core catalog, P0 visual catalog, visual asset manifest,
PracticeQuestionVisual component, or `practice_visual_*` media resources.

## Future extension

The domain still reserves `sourceType = AI_GENERATED`.

Future generated content must use the same Paper/Question contract, declare `track`, pass
`PracticeContentValidator.validatePaper(...)`, remain within the target audience scope, and be
published as an immutable version.

Do not create a parallel AI-only model or bypass content validation, audience policy, or history
immutability.
