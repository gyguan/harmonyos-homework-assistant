# Homework Understanding Rules · rules-v1.0

Pipeline order:

1. Teacher Resolver
2. Homework Classifier
3. Context Grouper by teacherId + subject
4. Revision Resolver
5. Task Extractor
6. CandidateAssignment mapping
7. Parent confirmation / edit / publish

Hard invariants:

- Unknown teacher => UNKNOWN, never guessed from surname.
- CHAT / NOTICE / UNKNOWN never enter homework context groups.
- Revision only affects the same teacher + subject context.
- A correction must append its messageId to affected task evidence.
- "以这条为准" replaces the current subject's homework task set.
- "第三题不用做" removes the referenced task when resolvable.
- "补充一下" adds tasks; it is evaluated after PREPARATION / NOTICE classification.
- A successful understanding pass with no candidates and no UNKNOWN yields EMPTY.
- UNKNOWN keeps the batch RECEIVED for human review.
- Candidate output makes the batch READY.
- No understanding stage publishes Assignment directly.
