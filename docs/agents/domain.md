# Domain Documentation

This repository uses a **single-context** domain layout.

## Files

- `CONTEXT.md`: shared vocabulary, domain boundaries and stable product rules that every agent should read before significant design or implementation work.
- `docs/adr/`: architectural decision records for decisions that are costly to reverse or easy to misunderstand later.
- GitHub Issues: feature-specific specifications and delivery tracking.

## Consumer rules

1. Read `CONTEXT.md` before inventing new names for domain concepts.
2. Prefer existing terms such as `Assignment`, `Resource`, `Submission`, `Textbook`, `Family` and `Candidate Assignment` when they fit.
3. If a feature introduces a genuinely new domain concept, update `CONTEXT.md` as part of the same change.
4. Use an ADR when a decision changes module boundaries, persistence shape, integration contracts, privacy posture or Phone/Pad architecture.
5. Keep feature detail out of `CONTEXT.md` when it belongs only to one issue/spec.
6. Do not let generated documentation drift from code: update or remove stale terms when implementation changes the model.
