alter table daily_homework_coverage
  add column parent_identity varchar(12);

update daily_homework_coverage coverage
set parent_identity = case
  when exists (
    select 1 from account a
    where a.id = coverage.account_id
      and a.display_name like '%妈%'
  ) then 'MOM'
  else 'DAD'
end
where parent_identity is null;

alter table daily_homework_coverage
  alter column parent_identity set not null;

alter table daily_homework_coverage
  add constraint chk_daily_homework_coverage_parent_identity
    check (parent_identity in ('DAD', 'MOM'));

alter table daily_homework_coverage
  drop constraint uq_daily_homework_coverage;

delete from daily_homework_coverage
where id in (
  select id from (
    select id,
      row_number() over (
        partition by family_id, student_id, task_date, parent_identity, subject_code
        order by updated_at desc, id desc
      ) as row_num
    from daily_homework_coverage
  ) ranked
  where ranked.row_num > 1
);

alter table daily_homework_coverage
  add constraint uq_daily_homework_coverage
    unique (family_id, student_id, task_date, parent_identity, subject_code);

create index idx_daily_homework_coverage_parent
  on daily_homework_coverage(family_id, student_id, task_date, parent_identity);
