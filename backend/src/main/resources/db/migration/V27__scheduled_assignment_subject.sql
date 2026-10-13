alter table scheduled_assignment_plan
  add column subject_code varchar(64);

update scheduled_assignment_plan p
set subject_code = t.subject_code
from scheduled_assignment_template t
where t.plan_id = p.id;

update scheduled_assignment_plan
set subject_code = 'OTHER'
where subject_code is null or btrim(subject_code) = '';

alter table scheduled_assignment_plan
  alter column subject_code set not null,
  alter column subject_code set default 'OTHER';
