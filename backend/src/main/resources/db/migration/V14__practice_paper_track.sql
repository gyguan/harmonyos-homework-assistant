alter table practice_paper
  add column if not exists track varchar(32) not null default 'TEXTBOOK_SYNC';

create index if not exists idx_practice_paper_track
  on practice_paper (grade, semester, subject, track, status);
