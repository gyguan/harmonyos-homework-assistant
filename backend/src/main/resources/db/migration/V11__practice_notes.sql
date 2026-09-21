create table if not exists practice_note (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(120) not null references student(id),
  attempt_id uuid not null references practice_attempt(id) on delete cascade,
  question_id varchar(180) not null references practice_question(id),
  content text not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  unique (attempt_id, question_id)
);

create index if not exists idx_practice_note_attempt
  on practice_note (attempt_id);

create index if not exists idx_practice_note_student_question
  on practice_note (family_id, student_id, question_id);
