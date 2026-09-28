alter table practice_paper
  add column if not exists family_id uuid references family(id),
  add column if not exists student_id varchar(120) references student(id);

create index if not exists idx_practice_paper_family_student
  on practice_paper (family_id, student_id, status, updated_at desc);

create table if not exists practice_generation (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(120) not null references student(id),
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

create index if not exists idx_practice_generation_family_student
  on practice_generation (family_id, student_id, created_at desc);
