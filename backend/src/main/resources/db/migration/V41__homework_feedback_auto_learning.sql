-- Automatic feedback learning is a scoped, reversible experience, not a global rule edit.
-- Existing manually-approved and historical teacher experiences remain unchanged.
ALTER TABLE homework_teacher_experience
  DROP CONSTRAINT chk_homework_teacher_experience_origin;
ALTER TABLE homework_teacher_experience
  ADD CONSTRAINT chk_homework_teacher_experience_origin
    CHECK (origin IN ('MANUAL','CONFIRMED_EDIT','FEEDBACK_APPROVED','FEEDBACK_AUTO'));
CREATE INDEX idx_homework_feedback_processing
  ON homework_organizer_feedback(family_id, student_id, processing_status, created_at DESC);
