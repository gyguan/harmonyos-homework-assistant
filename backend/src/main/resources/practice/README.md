# Practice preset content

`preset-catalog.json` is the canonical source for built-in Practice papers.

## Content workflow

1. Add a **new paper ID or new version** in `preset-catalog.json`.
2. Keep published versions immutable. If any question, answer, explanation, or metadata needs a semantic change after release, increment `version`.
3. Run:
   `python scripts/generate_practice_catalog.py`
4. Run:
   `python scripts/validate_practice_content.py`
5. Commit the JSON source and generated `PresetPracticeCatalog.ets` together.

The backend validates the catalog again at startup before importing missing versions into PostgreSQL. It never rewrites an existing published paper version.

## Quality rules

The gate validates:

- schema version and required fields
- globally unique question IDs
- unique `paperId + version`
- contiguous question order
- declared question count
- legal grade / subject / difficulty / type
- non-empty explanations, hints, and tags
- no duplicate stems inside one paper
- choice answers reference declared options
- numeric answers are parseable
- G1-G6 coverage for Chinese, Math, and English
- generated client metadata is synchronized with the JSON source

## AI-generated extension

The domain already reserves `sourceType = AI_GENERATED`.

Future AI paper generation should produce the same `PracticeContentCatalog.Paper` contract and call
`PracticeContentValidator.validatePaper(...)` **before publication**. AI content must then be persisted as a new immutable paper version and follows the same Attempt/history rules as PRESET content.

Do not create a second AI-only question model or bypass the validator.
