alter table assignment add column if not exists assignment_type varchar(16);
alter table assignment add column if not exists subject_code varchar(32);
alter table assignment add column if not exists due_at timestamptz;
alter table assignment add column if not exists due_timezone varchar(64);

update assignment
set assignment_type = 'SCHOOL'
where assignment_type is null or assignment_type = '';

update assignment
set subject_code = case subject
  when '语文' then 'CHINESE'
  when '数学' then 'MATH'
  when '英语' then 'ENGLISH'
  else 'OTHER'
end
where subject_code is null or subject_code = '';

update assignment
set due_timezone = 'Asia/Shanghai'
where due_timezone is null or due_timezone = '';

alter table assignment alter column assignment_type set default 'SCHOOL';
alter table assignment alter column assignment_type set not null;
alter table assignment alter column subject_code set default 'OTHER';
alter table assignment alter column subject_code set not null;
alter table assignment alter column due_timezone set default 'Asia/Shanghai';
alter table assignment alter column due_timezone set not null;

create index if not exists idx_assignment_family_student_due_at
  on assignment (family_id, student_id, due_at);
