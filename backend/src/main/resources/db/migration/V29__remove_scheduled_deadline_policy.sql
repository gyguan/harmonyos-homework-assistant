alter table scheduled_assignment_template drop column if exists due_policy;
alter table scheduled_assignment_template drop column if exists due_time;
alter table scheduled_assignment_template drop column if exists due_offset_minutes;
