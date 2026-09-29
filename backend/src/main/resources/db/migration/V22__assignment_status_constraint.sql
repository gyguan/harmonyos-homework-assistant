alter table assignment drop constraint if exists chk_assignment_status;
alter table assignment
  add constraint chk_assignment_status
  check (status in (
    'NOT_STARTED',
    'IN_PROGRESS',
    'PAUSED',
    'READY_TO_SUBMIT',
    'SUBMITTED',
    'COMPLETED',
    'NEEDS_REWORK',
    'OVERDUE'
  ));
