alter table practice_attempt
  add column if not exists source_attempt_id uuid references practice_attempt(id);

create index if not exists idx_practice_attempt_history
  on practice_attempt (family_id, student_id, started_at desc);

create index if not exists idx_practice_attempt_source
  on practice_attempt (source_attempt_id);
