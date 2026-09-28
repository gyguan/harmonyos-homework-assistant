create table scheduled_assignment_plan (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id) on delete cascade,
  plan_type varchar(32) not null,
  name varchar(300) not null,
  schedule_type varchar(24) not null,
  schedule_time time not null,
  weekdays varchar(80) not null default '',
  start_date date not null,
  end_date date,
  timezone varchar(64) not null default 'Asia/Shanghai',
  status varchar(16) not null default 'ENABLED',
  next_fire_at timestamp with time zone,
  last_fire_at timestamp with time zone,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  version bigint not null default 0
);

create index idx_scheduled_assignment_plan_due
  on scheduled_assignment_plan (status, next_fire_at)
  where next_fire_at is not null;

create index idx_scheduled_assignment_plan_student
  on scheduled_assignment_plan (family_id, student_id, created_at desc);

create table scheduled_assignment_template (
  plan_id uuid primary key references scheduled_assignment_plan(id) on delete cascade,
  assignment_type varchar(32) not null default 'EXTRA',
  subject varchar(80) not null,
  subject_code varchar(64) not null,
  title varchar(300) not null,
  instruction varchar(1000) not null,
  expected_minutes integer not null,
  due_policy varchar(32) not null,
  due_time time,
  due_offset_minutes integer,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create table scheduled_assignment_run (
  id uuid primary key,
  plan_id uuid not null references scheduled_assignment_plan(id) on delete cascade,
  scheduled_fire_at timestamp with time zone not null,
  trigger_source varchar(24) not null,
  status varchar(16) not null,
  assignment_id varchar(120),
  skip_reason varchar(200) not null default '',
  error_message varchar(500) not null default '',
  retry_count integer not null default 0,
  created_at timestamp with time zone not null,
  finished_at timestamp with time zone,
  constraint uq_scheduled_assignment_run unique (plan_id, scheduled_fire_at)
);

create index idx_scheduled_assignment_run_plan
  on scheduled_assignment_run (plan_id, scheduled_fire_at desc);
