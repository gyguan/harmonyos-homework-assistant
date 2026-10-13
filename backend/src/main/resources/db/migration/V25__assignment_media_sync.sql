create table assignment_media_sync (
  id uuid primary key,
  family_id uuid not null references family(id),
  assignment_id varchar(120) not null references assignment(id) on delete cascade,
  media_fingerprint varchar(64) not null,
  status varchar(16) not null,
  sync_version integer not null default 1,
  audio_resource_id uuid references assignment_resource(id) on delete set null,
  audio_duration_ms bigint not null default 0,
  confidence double precision not null default 0,
  timeline_json text not null,
  analysis_model varchar(120) not null default '',
  transcription_model varchar(120) not null default '',
  attempt_count integer not null default 0,
  next_retry_at timestamp with time zone not null,
  error_code varchar(80) not null default '',
  error_message varchar(500) not null default '',
  started_at timestamp with time zone,
  finished_at timestamp with time zone,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null,
  constraint uq_assignment_media_sync_assignment unique (family_id, assignment_id),
  constraint ck_assignment_media_sync_status check (status in ('PENDING', 'RUNNING', 'READY', 'FAILED'))
);

create index idx_assignment_media_sync_queue
  on assignment_media_sync (status, next_retry_at, created_at);

create index idx_assignment_media_sync_fingerprint
  on assignment_media_sync (family_id, media_fingerprint, finished_at desc)
  where status = 'READY';
