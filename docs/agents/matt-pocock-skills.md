# Matt Pocock Skills Integration

## Source

- Upstream: `https://github.com/mattpocock/skills`
- Integration mode: project-local, editable skills installed with the upstream-recommended `skills` installer
- Recorded upstream commit: `3cca18b368ae95cdbdebbff572ccafa662551015`
- License: MIT

## Why this project uses it

The project uses these skills as an engineering workflow, not as runtime application dependencies. They help keep product decisions, domain language, implementation plans, tests and reviews aligned while the HarmonyOS app evolves.

## Recommended skill set

Install at least:

- `setup-matt-pocock-skills`
- `grill-with-docs`
- `to-spec`
- `domain-modeling`
- `prototype`
- `codebase-design`
- `tdd`
- `diagnosing-bugs`
- `code-review`
- `implement`

Optional later:

- `to-tickets`
- `triage`
- `improve-codebase-architecture`
- `research`

## Installation

From the repository root, run the official installer and select the skills above:

`npx skills@latest add mattpocock/skills`

When the installer asks which agents to target, install them for the coding agent(s) actually used on this repository. Do not install both the Claude managed plugin and editable local copies for the same agent, because that creates duplicate skills.

After installation, run `setup-matt-pocock-skills` once. This repository has already prepared its intended configuration:

- Issue tracker: GitHub Issues
- Domain layout: single-context
- Shared language: root `CONTEXT.md`
- ADR directory: `docs/adr/`
- Agent instructions: `AGENTS.md`

## Upgrade policy

Do not silently update engineering skills during feature work. Upgrade intentionally, review upstream changes, then update `.agents/matt-pocock-skills.lock.json` with the new upstream commit.

## Usage in this project

For a new product feature, default flow is:

1. Clarify ambiguous product/interaction decisions with `grill-with-docs`.
2. Update `CONTEXT.md` if new domain language appears.
3. Convert the agreed design to an implementable spec with `to-spec`.
4. Use `prototype` for uncertain UI/state-flow decisions, especially Phone/Pad responsive behavior.
5. Validate module seams with `domain-modeling` and `codebase-design`.
6. Implement critical rules with `tdd` and use `diagnosing-bugs` when a reproducible defect appears.
7. Run `code-review` before merging.

For small, obvious changes, skip ceremony that adds no value; keep the same vocabulary and constraints from `AGENTS.md` and `CONTEXT.md`.
