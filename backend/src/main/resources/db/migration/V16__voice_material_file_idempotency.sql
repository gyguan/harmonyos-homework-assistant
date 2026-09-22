create unique index uq_voice_material_file_package_name_type
  on voice_material_file (package_id, resource_type, relative_name);
