create table if not exists practice_paper (
  paper_key varchar(180) primary key,
  paper_id varchar(140) not null,
  version integer not null,
  grade varchar(16) not null,
  subject varchar(32) not null,
  title varchar(240) not null,
  description varchar(1000) not null,
  difficulty varchar(16) not null,
  question_count integer not null,
  estimated_minutes integer not null,
  tags_json text not null,
  source_type varchar(32) not null,
  status varchar(32) not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  unique (paper_id, version)
);

create table if not exists practice_question (
  id varchar(180) primary key,
  paper_key varchar(180) not null references practice_paper(paper_key),
  order_no integer not null,
  question_type varchar(32) not null,
  stem text not null,
  options_json text not null,
  answer_spec text not null,
  explanation text not null,
  hints_json text not null,
  tags_json text not null,
  unique (paper_key, order_no)
);

create index if not exists idx_practice_question_paper
  on practice_question (paper_key, order_no);

create table if not exists practice_attempt (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(120) not null references student(id),
  paper_id varchar(140) not null,
  paper_version integer not null,
  attempt_no integer not null,
  mode varchar(32) not null,
  status varchar(32) not null,
  question_ids_json text not null,
  started_at timestamp with time zone not null,
  submitted_at timestamp with time zone,
  elapsed_seconds bigint not null default 0,
  score integer not null default 0,
  max_score integer not null default 0,
  correct_count integer not null default 0,
  wrong_count integer not null default 0
);

create index if not exists idx_practice_attempt_student_paper
  on practice_attempt (family_id, student_id, paper_id, started_at desc);

create table if not exists practice_answer (
  id uuid primary key,
  family_id uuid not null references family(id),
  attempt_id uuid not null references practice_attempt(id) on delete cascade,
  question_id varchar(180) not null references practice_question(id),
  answer_value text not null,
  is_correct boolean,
  score integer not null default 0,
  answered_at timestamp with time zone not null,
  unique (attempt_id, question_id)
);

create index if not exists idx_practice_answer_attempt
  on practice_answer (attempt_id);
