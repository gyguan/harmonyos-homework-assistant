alter table assignment add column expected_minutes integer not null default 20;
alter table assignment add column started_at_epoch_ms bigint not null default 0;
alter table assignment add column finished_at_epoch_ms bigint not null default 0;
alter table assignment add column elapsed_seconds bigint not null default 0;

alter table assignment add constraint chk_assignment_expected_minutes check (expected_minutes between 1 and 240);
alter table assignment add constraint chk_assignment_elapsed_seconds check (elapsed_seconds >= 0);
