alter table assignment
  add column if not exists create_fingerprint varchar(64);

create index if not exists idx_assignment_create_fingerprint
  on assignment (family_id, student_id, create_fingerprint)
  where create_fingerprint is not null;
