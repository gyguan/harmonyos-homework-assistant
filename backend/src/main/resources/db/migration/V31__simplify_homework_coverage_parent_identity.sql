alter table daily_homework_coverage
  add column parent_identity varchar(12);

update daily_homework_coverage
set parent_identity = 'DAD'
where parent_identity is null;

alter table daily_homework_coverage
  alter column parent_identity set not null;

alter table daily_homework_coverage
  add constraint chk_daily_homework_coverage_parent_identity
    check (parent_identity in ('DAD', 'MOM'));

alter table daily_homework_coverage
  drop constraint uq_daily_homework_coverage;

alter table daily_homework_coverage
  add constraint uq_daily_homework_coverage
    unique (family_id, student_id, task_date, account_id, parent_identity, subject_code);

create index idx_daily_homework_coverage_parent
  on daily_homework_coverage(family_id, student_id, task_date, parent_identity);
