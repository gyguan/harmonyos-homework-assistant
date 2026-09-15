package com.xiaoban.homework.storage;

import java.nio.file.Path;
import java.util.UUID;
import org.springframework.web.multipart.MultipartFile;

public interface FileStorage {
  StoredFile save(UUID photoId, MultipartFile file);
  Path resolve(String storagePath);
  void delete(String storagePath);
  record StoredFile(String storagePath, String originalName, String contentType, long sizeBytes) {}
}
