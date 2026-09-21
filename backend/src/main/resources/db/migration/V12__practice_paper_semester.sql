alter table practice_paper
  add column if not exists semester varchar(16) not null default 'ALL';

create index if not exists idx_practice_paper_audience
  on practice_paper (grade, semester, subject, status);
