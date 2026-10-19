-- A heuristic can only suggest split/merge for human review.
-- These records never become an AI rule without parent confirmation.
alter table homework_organizer_review_difference
  drop constraint ck_homework_review_change_type;
alter table homework_organizer_review_difference
  add constraint ck_homework_review_change_type
  check (change_type in ('CHANGED', 'REMOVED', 'ADDED', 'SPLIT_SUSPECTED', 'MERGE_SUSPECTED'));
