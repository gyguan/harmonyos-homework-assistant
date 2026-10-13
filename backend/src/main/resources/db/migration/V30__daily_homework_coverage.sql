create table daily_homework_coverage (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  task_date date not null,
  account_id uuid not null references account(id) on delete cascade,
  subject_code varchar(20) not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  constraint chk_daily_homework_coverage_subject
    check (subject_code in ('ALL', 'CHINESE', 'MATH', 'ENGLISH')),
  constraint uq_daily_homework_coverage
    unique (family_id, student_id, task_date, account_id, subject_code)
);

create index idx_daily_homework_coverage_lookup
  on daily_homework_coverage(family_id, student_id, task_date, updated_at desc);
