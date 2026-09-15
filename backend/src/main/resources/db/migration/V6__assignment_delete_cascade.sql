alter table submission drop constraint if exists submission_assignment_id_fkey;
alter table submission
  add constraint submission_assignment_id_fkey
  foreign key (assignment_id) references assignment(id) on delete cascade;

alter table submission_photo drop constraint if exists submission_photo_assignment_id_fkey;
alter table submission_photo
  add constraint submission_photo_assignment_id_fkey
  foreign key (assignment_id) references assignment(id) on delete cascade;
