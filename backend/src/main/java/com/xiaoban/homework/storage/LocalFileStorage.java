package com.xiaoban.homework.storage;

import com.xiaoban.homework.common.ApiExceptions;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Component
public class LocalFileStorage implements FileStorage {
  private final Path root;
  public LocalFileStorage(@Value("${app.storage.root:./data/uploads}") String root) { this.root = Path.of(root).toAbsolutePath().normalize(); }

  @Override
  public StoredFile save(UUID photoId, MultipartFile file) {
    String original = file.getOriginalFilename() == null ? "photo.jpg" : file.getOriginalFilename();
    String ext = extension(original);
    String relative = photoId + ext;
    Path target = root.resolve(relative).normalize();
    if (!target.startsWith(root)) throw new ApiExceptions.BadRequest("非法文件路径");
    try {
      Files.createDirectories(root);
      Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
      String contentType = file.getContentType() == null ? "application/octet-stream" : file.getContentType();
      return new StoredFile(relative, original, contentType, file.getSize());
    } catch (IOException e) {
      throw new IllegalStateException("保存作业照片失败", e);
    }
  }

  @Override public Path resolve(String storagePath) {
    Path path = root.resolve(storagePath).normalize();
    if (!path.startsWith(root)) throw new ApiExceptions.BadRequest("非法文件路径");
    return path;
  }

  @Override public void delete(String storagePath) {
    Path path = resolve(storagePath);
    try {
      Files.deleteIfExists(path);
    } catch (IOException e) {
      throw new IllegalStateException("删除作业照片失败", e);
    }
  }

  private String extension(String name) {
    int dot = name.lastIndexOf('.');
    if (dot < 0 || dot < name.length() - 6) return ".jpg";
    String ext = name.substring(dot).toLowerCase();
    return ext.matches("\\.[a-z0-9]{1,5}") ? ext : ".jpg";
  }
}
