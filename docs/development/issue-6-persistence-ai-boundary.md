# Issue #6 implementation checkpoint

Branch: `feat/issue-6-persistence-ai-boundary`

## Goal

Move V0.1 from an in-memory-only demo to a locally durable architecture while keeping future OCR / LLM providers replaceable.

## Persistence boundary

The dependency direction is:

`UI -> HomeworkStore -> HomeworkPersistence <- PreferencesHomeworkPersistence`

Only the infrastructure adapter imports `@kit.ArkData`.

V0.1 persists one versioned JSON snapshot containing:

- Assignment[]
- CandidateAssignment[]
- Submission[]
- submissionSequence

`EntryAbility` restores the snapshot before `pages/Index` is loaded. If no snapshot exists, the existing Mock seed becomes the first persisted state.

The Store uses a coalescing persistence queue so rapid state changes cannot finish out of order and leave an older snapshot on disk.

Preferences is intentionally a V0.1 adapter, not a permanent domain decision. If query volume or data size grows, a future RDB adapter can implement the same persistence port without changing UI pages or the assignment state machine.

## Import / AI boundary

The dependency direction is:

`Import UI -> HomeworkImportService -> HomeworkImportPipeline -> HomeworkTextExtractor + HomeworkAssignmentParser`

Current adapters:

- `MockHomeworkTextExtractor`
- `MockHomeworkAssignmentParser`

Future adapters can replace either side independently:

- screenshot / file / shared-content extraction can replace `HomeworkTextExtractor`;
- LLM or deterministic semantic parsing can replace `HomeworkAssignmentParser`.

`RawHomeworkImport` now retains:

- source kind
- source label
- resource URI
- raw text when already available

This allows a later OCR adapter to read the source asset without changing the page contract.

## Duplicate protection

Re-running the parser after an Assignment has already been published will not recreate the same published Candidate. `HomeworkStore` filters Candidates whose `candidateId` is already represented by an Assignment.

## Manual validation

1. Build and run the app.
2. Parent -> Import -> simulate reparse -> Confirmation.
3. Publish an Assignment.
4. Student -> start -> mark done -> mock submit.
5. Parent -> Progress and verify `已提交` plus one submission.
6. Fully terminate the app.
7. Start the app again.
8. Verify the same Assignment status and Submission are still present.

## Architecture gate

`python scripts/validate_harmony_project.py`

The gate now checks that:

- ArkData does not leak outside the persistence adapter;
- HomeworkStore depends on the persistence port;
- EntryAbility restores Store state before UI load;
- OCR/text extraction and assignment parsing have separate ports;
- the Import page depends on the application service, not concrete Mock/AI adapters;
- source metadata needed by future OCR is preserved.

## Not implemented yet

- real OCR
- real LLM calls
- API key management
- RDB persistence
- cloud synchronization
- account/authentication persistence
