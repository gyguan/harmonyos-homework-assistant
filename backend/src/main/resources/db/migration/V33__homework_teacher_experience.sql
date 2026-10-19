-- 家庭内按学生、老师、学科隔离的作业理解经验；不迁移/猜测老师身份。
create table homework_teacher_experience (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  teacher_name varchar(80) not null,
  subject varchar(20) not null,
  cue varchar(120) not null,
  interpretation varchar(600) not null,
  example_source varchar(400) not null default '',
  example_result varchar(400) not null default '',
  origin varchar(20) not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  constraint chk_homework_teacher_experience_origin check (origin in ('MANUAL', 'CONFIRMED_EDIT'))
);
create index idx_homework_teacher_experience_student
  on homework_teacher_experience(family_id, student_id, teacher_name, updated_at desc);
