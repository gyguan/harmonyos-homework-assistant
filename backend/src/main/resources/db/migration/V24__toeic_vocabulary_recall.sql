create table toeic_vocabulary_recall (
  id uuid primary key,
  account_id uuid not null references account(id) on delete cascade,
  vocabulary_id varchar(120) not null,
  remembered boolean not null,
  streak integer not null,
  total_reviews integer not null,
  next_due_at timestamp with time zone not null,
  last_reviewed_at timestamp with time zone not null,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  constraint uk_toeic_vocabulary_recall unique (account_id, vocabulary_id)
);

create index idx_toeic_vocabulary_recall_account
  on toeic_vocabulary_recall (account_id, updated_at desc);
