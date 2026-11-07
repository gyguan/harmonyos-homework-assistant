-- AI candidate originals only. Do not store images, household chat, or full source messages.
-- Client importId is recorded with each original item and survives an app restart.
create table homework_organizer_ai_snapshot (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  batch_id varchar(140) not null,
  candidate_id varchar(180) not null,
  teacher_name varchar(80) not null default '',
  subject varchar(20) not null,
  title varchar(400) not null,
  instruction varchar(1500) not null,
  textbook_ref varchar(100) not null default '',
  task_date varchar(30) not null,
  expected_minutes integer not null,
  source_excerpt varchar(500) not null default '',
  created_at timestamptz not null,
  constraint uq_homework_ai_snapshot unique(family_id,student_id,batch_id,candidate_id)
);
create index idx_homework_ai_snapshot_batch
  on homework_organizer_ai_snapshot(family_id,student_id,batch_id);
