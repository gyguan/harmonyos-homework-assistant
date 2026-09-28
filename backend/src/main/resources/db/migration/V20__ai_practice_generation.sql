alter table practice_paper
  add column if not exists family_id uuid references family(id);

create index if not exists idx_practice_paper_family
  on practice_paper (family_id, status, updated_at desc);

create index if not exists idx_practice_paper_catalog
  on practice_paper (status, grade, subject, semester, track, family_id);

create table if not exists practice_paper_audience (
  id uuid primary key,
  paper_key varchar(180) not null references practice_paper(paper_key) on delete cascade,
  family_id uuid not null references family(id),
  student_id varchar(120) not null references student(id),
  assigned_at timestamp with time zone not null,
  constraint uk_practice_paper_audience unique (paper_key, student_id)
);

create index if not exists idx_practice_paper_audience_student
  on practice_paper_audience (family_id, student_id, assigned_at desc);

create table if not exists practice_generation (
  id uuid primary key,
  family_id uuid not null references family(id),
  reference_student_id varchar(120) not null references student(id),
  reference_textbook_context text not null default '',
  subject varchar(32) not null,
  semester varchar(16) not null,
  track varchar(32) not null,
  difficulty varchar(16) not null,
  question_count integer not null,
  requirement text not null,
  status varchar(32) not null,
  generated_json text,
  paper_id varchar(140),
  paper_version integer,
  model varchar(120),
  error_message varchar(1000),
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create index if not exists idx_practice_generation_family_reference_student
  on practice_generation (family_id, reference_student_id, created_at desc);
