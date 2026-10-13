alter table assignment add column if not exists task_date date;

update assignment
set task_date = case
  when due_at is not null then (due_at at time zone 'Asia/Shanghai')::date
  else (created_at at time zone 'Asia/Shanghai')::date
end
where task_date is null;

alter table assignment alter column task_date set not null;

create index if not exists idx_assignment_family_student_task_date
  on assignment (family_id, student_id, task_date);
