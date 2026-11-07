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
      // 同一 photoId 重传会覆盖源文件；缓存键只有「文件名 + w」，必须先失效旧缩略图，
      // 否则秒级 mtime 精度下家长看到的仍是上一版照片。
      deleteDerivedThumbnails(target);
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
      // 缩略图是源图的派生物：源图删掉后留着不仅泄漏作业照片内容，还让 .thumbs 只增不减。
      deleteDerivedThumbnails(path);
    } catch (IOException e) {
      throw new IllegalStateException("删除作业照片失败", e);
    }
  }

  /** 删除 `<源文件目录>/.thumbs/<源文件名去扩展名>-w*.jpg`，best-effort，不影响源文件操作结果。 */
  private void deleteDerivedThumbnails(Path source) {
    Path parent = source.getParent();
    if (parent == null) return;
    Path thumbs = parent.resolve(ImageThumbnailCache.THUMB_DIRECTORY);
    if (!Files.isDirectory(thumbs)) return;
    String name = source.getFileName().toString();
    int dot = name.lastIndexOf('.');
    String prefix = (dot > 0 ? name.substring(0, dot) : name) + "-w";
    try (var entries = Files.list(thumbs)) {
      entries.forEach(entry -> {
        String entryName = entry.getFileName().toString();
        if (!entryName.startsWith(prefix) || !entryName.endsWith(".jpg")) return;
        try {
          Files.deleteIfExists(entry);
        } catch (IOException ignored) {
          // 派生缓存清理失败不影响主流程，下一次同名请求会被 save 的失效逻辑覆盖。
        }
      });
    } catch (IOException ignored) {
      // 同上：缩略图目录不可读时保持原行为。
    }
  }

  private String extension(String name) {
    int dot = name.lastIndexOf('.');
    if (dot < 0 || dot < name.length() - 6) return ".jpg";
    String ext = name.substring(dot).toLowerCase();
    return ext.matches("\\.[a-z0-9]{1,5}") ? ext : ".jpg";
  }
}
