create table auth_session (
  token varchar(128) primary key,
  account_id uuid not null references account(id) on delete cascade,
  family_id uuid not null references family(id) on delete cascade,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone not null
);
create index idx_auth_session_family on auth_session(family_id, expires_at);

create table tutor_session (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id),
  assignment_id varchar(120) not null references assignment(id) on delete cascade,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  unique(family_id, assignment_id)
);
create index idx_tutor_session_student on tutor_session(family_id, student_id, updated_at desc);

create table tutor_message (
  id uuid primary key,
  session_id uuid not null references tutor_session(id) on delete cascade,
  role varchar(20) not null,
  content text not null,
  created_at timestamp with time zone not null
);
create index idx_tutor_message_session on tutor_message(session_id, created_at);
