-- AI generated, evidence-grounded feedback experiences remain scoped to a student,
-- reversible and auditable through the existing source_feedback_id relationship.
-- Do not silently activate historical disabled experiences.
ALTER TABLE homework_teacher_experience
  DROP CONSTRAINT chk_homework_teacher_experience_origin;
ALTER TABLE homework_teacher_experience
  ADD CONSTRAINT chk_homework_teacher_experience_origin
    CHECK (origin IN ('MANUAL','CONFIRMED_EDIT','FEEDBACK_APPROVED','FEEDBACK_AUTO','FEEDBACK_AI'));

CREATE INDEX idx_homework_teacher_experience_learning
  ON homework_teacher_experience(family_id, student_id, active, updated_at DESC);
