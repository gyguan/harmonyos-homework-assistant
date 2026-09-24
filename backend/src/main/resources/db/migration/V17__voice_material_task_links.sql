create table voice_material_task_link (
  id varchar(120) primary key,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id),
  package_id uuid not null references voice_material_package(id) on delete cascade,
  assignment_id varchar(120) not null,
  assignment_title varchar(300) not null default '',
  create_mode varchar(16) not null,
  request_id varchar(120),
  created_at timestamp with time zone not null
);

create index idx_voice_material_task_link_package
  on voice_material_task_link (family_id, package_id, created_at desc);

create index idx_voice_material_task_link_assignment
  on voice_material_task_link (family_id, assignment_id);

create index idx_voice_material_task_link_student
  on voice_material_task_link (family_id, student_id, created_at desc);

create unique index uq_voice_material_task_link_request
  on voice_material_task_link (family_id, request_id)
  where request_id is not null;

insert into voice_material_task_link (
  id, family_id, student_id, package_id, assignment_id,
  assignment_title, create_mode, request_id, created_at
)
select
  'legacy-' || p.id::text,
  p.family_id,
  p.student_id,
  p.id,
  p.consumed_assignment_id,
  coalesce(a.title, p.title, ''),
  'LEGACY',
  null,
  coalesce(p.consumed_at, p.updated_at, p.created_at)
from voice_material_package p
left join assignment a
  on a.id = p.consumed_assignment_id
 and a.family_id = p.family_id
where p.consumed_assignment_id is not null
  and p.consumed_assignment_id <> ''
  and not exists (
    select 1
    from voice_material_task_link l
    where l.family_id = p.family_id
      and l.assignment_id = p.consumed_assignment_id
  );

update voice_material_package
set status = 'READY',
    updated_at = now()
where status = 'CONSUMED';
