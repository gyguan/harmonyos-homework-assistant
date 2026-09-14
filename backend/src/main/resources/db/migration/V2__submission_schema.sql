create table submission (
  id uuid primary key,
  family_id uuid not null references family(id),
  assignment_id varchar(120) not null references assignment(id),
  submitted_at timestamp with time zone not null,
  created_at timestamp with time zone not null
);
create index idx_submission_assignment on submission(family_id, assignment_id, submitted_at desc);

create table submission_photo (
  id uuid primary key,
  submission_id uuid not null references submission(id) on delete cascade,
  family_id uuid not null references family(id),
  assignment_id varchar(120) not null references assignment(id),
  storage_path varchar(1000) not null,
  original_name varchar(300) not null,
  content_type varchar(160) not null,
  size_bytes bigint not null
);
create index idx_submission_photo_submission on submission_photo(submission_id);
