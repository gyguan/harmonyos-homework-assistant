-- 家长反馈分类配置：界面展示、排序、启停、是否必填说明均由数据库驱动。
create table homework_feedback_type (
  code varchar(48) primary key,
  label varchar(80) not null,
  description varchar(240) not null default '',
  requires_comment boolean not null default false,
  enabled boolean not null default true,
  display_order integer not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

insert into homework_feedback_type(code, label, description, requires_comment, display_order) values
  ('OMISSION', '漏掉了作业', '有老师布置的内容没有整理出来，请说明遗漏项', true, 10),
  ('WRONG_SPLIT', '拆分或合并不对', '多项合成一项，或一项被拆成多项', false, 20),
  ('WRONG_SUBJECT', '学科不对', '语文、数学、英语等科目识别错误', false, 30),
  ('SHORTHAND', '老师缩写理解错了', '例如 U、国、订小白等缩写含义错误', true, 40),
  ('WRONG_CONTENT', '内容或要求不准确', '课文、页码、题号、遍数或完成要求不准确', false, 50),
  ('WRONG_DATE', '作业日期不对', '作业日期、提交日期或截止日期识别不对', false, 60),
  ('DUPLICATE', '重复生成作业', '同一项作业被重复生成', false, 70),
  ('OTHER', '其他问题', '填写具体反馈，帮助改进整理效果', true, 90);

create table homework_organizer_feedback (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  client_request_id varchar(160) not null,
  candidate_id varchar(180) not null,
  batch_id varchar(180) not null default '',
  teacher_name varchar(80) not null default '',
  subject varchar(20) not null,
  feedback_type_code varchar(48) not null references homework_feedback_type(code),
  source_label varchar(200) not null default '',
  source_excerpt varchar(500) not null default '',
  original_title varchar(400) not null default '',
  current_title varchar(400) not null default '',
  details varchar(1200) not null default '',
  processing_status varchar(20) not null default 'NEW',
  created_at timestamp with time zone not null,
  constraint uq_homework_organizer_feedback_request
    unique (family_id, student_id, client_request_id)
);
create index idx_homework_organizer_feedback_student
  on homework_organizer_feedback(family_id, student_id, created_at desc);
create index idx_homework_organizer_feedback_teacher
  on homework_organizer_feedback(family_id, student_id, teacher_name, feedback_type_code);
