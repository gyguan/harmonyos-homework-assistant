create table submission_resource (
  id uuid primary key,
  submission_id uuid not null references submission(id) on delete cascade,
  family_id uuid not null references family(id),
  assignment_id varchar(120) not null references assignment(id) on delete cascade,
  resource_type varchar(24) not null,
  storage_path varchar(1000) not null,
  original_name varchar(300) not null,
  content_type varchar(160) not null,
  size_bytes bigint not null,
  duration_ms bigint not null default 0,
  sort_order integer not null default 0,
  created_at timestamp with time zone not null
);
create index idx_submission_resource_submission
  on submission_resource(submission_id, sort_order, id);
create index idx_submission_resource_assignment
  on submission_resource(family_id, assignment_id);

insert into submission_resource (
  id, submission_id, family_id, assignment_id, resource_type, storage_path,
  original_name, content_type, size_bytes, duration_ms, sort_order, created_at
)
select
  p.id, p.submission_id, p.family_id, p.assignment_id, 'IMAGE', p.storage_path,
  p.original_name, p.content_type, p.size_bytes, 0,
  row_number() over (partition by p.submission_id order by p.id) - 1,
  s.created_at
from submission_photo p
join submission s on s.id = p.submission_id;
