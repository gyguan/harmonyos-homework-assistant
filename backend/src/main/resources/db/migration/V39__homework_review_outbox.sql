-- Durable reconciliation is enqueued in the SAME DB transaction as batch publishing.
-- No copied homework text or images: only validated candidate identifiers.
create table homework_review_outbox (
  id uuid primary key,
  family_id uuid not null references family(id) on delete cascade,
  student_id varchar(80) not null references student(id) on delete cascade,
  batch_id varchar(140) not null,
  candidate_ids varchar(10000) not null,
  status varchar(16) not null default 'PENDING',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null,
  last_error varchar(200) not null default '',
  created_at timestamptz not null,
  updated_at timestamptz not null,
  constraint uq_homework_review_outbox_batch unique(family_id,student_id,batch_id),
  constraint ck_homework_review_outbox_state check(status in ('PENDING','COMPLETED','FAILED'))
);
create index idx_homework_review_outbox_due
  on homework_review_outbox(status,next_attempt_at);
