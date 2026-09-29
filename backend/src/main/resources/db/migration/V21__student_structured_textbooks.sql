alter table student
  add column chinese_textbook varchar(160) not null default '',
  add column math_textbook varchar(160) not null default '',
  add column english_textbook varchar(160) not null default '',
  add column other_textbooks varchar(500) not null default '';
