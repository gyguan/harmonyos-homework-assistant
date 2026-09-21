alter table practice_question
  add column if not exists visual_spec_json text not null default '{}';
