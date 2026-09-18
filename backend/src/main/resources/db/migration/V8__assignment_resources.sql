alter table assignment add column if not exists content_type varchar(32);

update assignment
set content_type = 'NORMAL'
where content_type is null or content_type = '';

alter table assignment alter column content_type set default 'NORMAL';
alter table assignment alter column content_type set not null;

create table if not exists assignment_resource (
  id uuid primary key,
  family_id uuid not null references family(id),
  assignment_id varchar(120) not null references assignment(id) on delete cascade,
  resource_type varchar(16) not null,
  storage_path varchar(500) not null,
  original_name varchar(300) not null,
  content_type varchar(160) not null,
  size_bytes bigint not null,
  sort_order integer not null,
  duration_ms bigint not null default 0,
  created_at timestamp with time zone not null
);

create index if not exists idx_assignment_resource_assignment
  on assignment_resource (family_id, assignment_id, sort_order);
