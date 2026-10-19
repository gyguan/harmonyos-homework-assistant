-- Teacher identity is per family and student; no surname inference or cross-student sharing.
create table homework_student_teacher (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  teacher_name varchar(80) not null,
  subject varchar(20) not null,
  enabled boolean not null default true,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  constraint uq_homework_student_teacher unique (family_id, student_id, teacher_name, subject)
);
create index idx_homework_student_teacher_family_student
  on homework_student_teacher (family_id, student_id, enabled, updated_at desc);

-- Structured post-publication corrections; evidence only, not a live AI rule.
create table homework_organizer_review_difference (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  batch_id varchar(180) not null,
  candidate_id varchar(180) not null,
  teacher_name varchar(80) not null default '',
  change_type varchar(24) not null,
  field_name varchar(32) not null,
  before_value varchar(1500) not null default '',
  after_value varchar(1500) not null default '',
  source_excerpt varchar(500) not null default '',
  created_at timestamptz not null,
  constraint ck_homework_review_change_type
    check (change_type in ('CHANGED', 'REMOVED', 'ADDED')),
  constraint uq_homework_review_diff
    unique (family_id, student_id, batch_id, candidate_id, change_type, field_name)
);
create index idx_homework_review_diff_student
  on homework_organizer_review_difference(family_id, student_id, created_at desc);
create index idx_homework_review_diff_teacher
  on homework_organizer_review_difference(family_id, student_id, teacher_name, field_name);
