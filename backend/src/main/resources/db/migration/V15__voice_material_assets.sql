create table media_asset (
  id uuid primary key,
  family_id uuid not null references family(id),
  storage_path varchar(500) not null,
  original_name varchar(300) not null,
  content_type varchar(160) not null,
  size_bytes bigint not null,
  sha256 varchar(64) not null,
  created_at timestamp with time zone not null,
  constraint uq_media_asset_family_hash unique (family_id, sha256, size_bytes)
);

create index idx_media_asset_family_created
  on media_asset (family_id, created_at desc);

alter table assignment_resource
  add column if not exists asset_id uuid references media_asset(id);

alter table assignment_resource
  alter column storage_path drop not null;

alter table assignment_resource
  add constraint ck_assignment_resource_storage_owner
  check (
    (storage_path is not null and asset_id is null)
    or
    (storage_path is null and asset_id is not null)
  );

create index idx_assignment_resource_asset
  on assignment_resource (asset_id)
  where asset_id is not null;

create table voice_material_batch (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id),
  directory_count integer not null default 0,
  ready_count integer not null default 0,
  invalid_count integer not null default 0,
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create index idx_voice_material_batch_family_student
  on voice_material_batch (family_id, student_id, created_at desc);

create table voice_material_package (
  id uuid primary key,
  batch_id uuid not null references voice_material_batch(id) on delete cascade,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id),
  directory_name varchar(300) not null,
  subject_code varchar(64) not null,
  title varchar(300) not null,
  expected_minutes integer not null default 15,
  due_at timestamp with time zone,
  assignment_type varchar(32) not null default 'EXTRA',
  status varchar(24) not null default 'UPLOADING',
  package_fingerprint varchar(64),
  consumed_assignment_id varchar(120),
  consumed_at timestamp with time zone,
  error_message varchar(500) not null default '',
  created_at timestamp with time zone not null,
  updated_at timestamp with time zone not null
);

create index idx_voice_material_package_queue
  on voice_material_package (family_id, student_id, status, directory_name, created_at);

create unique index uq_voice_material_package_fingerprint
  on voice_material_package (family_id, student_id, package_fingerprint)
  where package_fingerprint is not null;

create table voice_material_file (
  id uuid primary key,
  package_id uuid not null references voice_material_package(id) on delete cascade,
  family_id uuid not null references family(id),
  asset_id uuid not null references media_asset(id),
  resource_type varchar(16) not null,
  relative_name varchar(300) not null,
  sort_order integer not null,
  created_at timestamp with time zone not null
);

create index idx_voice_material_file_package
  on voice_material_file (family_id, package_id, sort_order, created_at);

create table voice_material_auto_create_record (
  id uuid primary key,
  family_id uuid not null references family(id),
  student_id varchar(80) not null references student(id),
  business_date date not null,
  package_id uuid not null references voice_material_package(id),
  assignment_id varchar(120) not null,
  created_at timestamp with time zone not null,
  constraint uq_voice_material_auto_daily unique (family_id, student_id, business_date)
);

create index idx_voice_material_auto_student
  on voice_material_auto_create_record (family_id, student_id, business_date desc);
