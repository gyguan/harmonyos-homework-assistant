create table family (
  id uuid primary key,
  name varchar(120) not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create table account (
  id uuid primary key,
  family_id uuid not null references family(id),
  login_name varchar(120) not null unique,
  password_hash varchar(200) not null,
  display_name varchar(120) not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create table student (
  id varchar(80) primary key,
  family_id uuid not null references family(id),
  name varchar(80) not null,
  grade varchar(80) not null,
  class_name varchar(80) not null,
  semester varchar(80) not null,
  textbook_summary varchar(500) not null default '',
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);
create index idx_student_family on student(family_id);

create table assignment (
  id varchar(120) primary key,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id),
  subject varchar(32) not null,
  title varchar(300) not null,
  instruction text not null,
  textbook_ref varchar(300) not null default '',
  due_text varchar(120) not null default '',
  status varchar(40) not null,
  source_label varchar(200) not null default '',
  source_excerpt text not null default '',
  version bigint not null default 0,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);
create index idx_assignment_family_student on assignment(family_id, student_id, updated_at desc);
