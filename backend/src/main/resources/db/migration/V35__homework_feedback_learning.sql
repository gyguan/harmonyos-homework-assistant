-- Database-configurable feedback-to-experience eligibility. SHORTHAND is the only
-- initially approved category: other feedback requires task-level review first.
alter table homework_feedback_type
  add column can_become_experience boolean not null default false;
update homework_feedback_type set can_become_experience = true where code = 'SHORTHAND';

-- Reversible learning. Keep the rule and its originating feedback for audit;
-- inactive experience is excluded from all AI prompts.
alter table homework_teacher_experience
  add column active boolean not null default true,
  add column source_feedback_id uuid references homework_organizer_feedback(id) on delete set null;
alter table homework_teacher_experience
  drop constraint chk_homework_teacher_experience_origin;
alter table homework_teacher_experience
  add constraint chk_homework_teacher_experience_origin
  check (origin in ('MANUAL', 'CONFIRMED_EDIT', 'FEEDBACK_APPROVED'));
create unique index uq_teacher_experience_source_feedback
  on homework_teacher_experience(source_feedback_id)
  where source_feedback_id is not null;
create index idx_teacher_experience_active
  on homework_teacher_experience(family_id, student_id, active, updated_at desc);
