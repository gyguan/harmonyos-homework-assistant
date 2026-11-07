-- Additive only: old snapshots / clients remain usable. No image bytes are persisted.
create table homework_source_evidence (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(120) not null references student(id) on delete cascade,
  batch_id varchar(140) not null,
  evidence_json text not null,
  created_at timestamptz not null,
  unique(family_id, student_id, batch_id)
);
