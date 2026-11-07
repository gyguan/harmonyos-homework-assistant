package com.xiaoban.homework.storage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Instant;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ImageThumbnailCacheTest {
  private final ImageThumbnailCache cache = new ImageThumbnailCache();

  @Test
  void rendersThumbnailWithBoundedLongSide(@TempDir Path dir) throws Exception {
    Path source = writeJpeg(dir.resolve("photo.jpg"), 1600, 1200);

    Optional<Path> thumbnail = cache.thumbnail(source, 320);

    assertTrue(thumbnail.isPresent());
    BufferedImage decoded = ImageIO.read(thumbnail.get().toFile());
    assertEquals(320, Math.max(decoded.getWidth(), decoded.getHeight()));
    assertEquals(240, decoded.getHeight());
    assertTrue(Files.size(thumbnail.get()) < Files.size(source));
  }

  @Test
  void secondCallReusesCachedFile(@TempDir Path dir) throws Exception {
    Path source = writeJpeg(dir.resolve("photo.jpg"), 800, 600);

    Path first = cache.thumbnail(source, 200).orElseThrow();
    FileTime stamp = Files.getLastModifiedTime(first);
    Path second = cache.thumbnail(source, 200).orElseThrow();

    assertEquals(first, second);
    assertEquals(stamp, Files.getLastModifiedTime(second));
  }

  @Test
  void regeneratesWhenSourceIsNewer(@TempDir Path dir) throws Exception {
    Path source = writeJpeg(dir.resolve("photo.jpg"), 800, 600);
    Path thumbnail = cache.thumbnail(source, 200).orElseThrow();

    // 缩略图比原图旧 —— 例如原图被同名重传过，必须重新生成。
    FileTime stale = FileTime.from(Instant.now().minusSeconds(3600));
    Files.setLastModifiedTime(thumbnail, stale);
    Path again = cache.thumbnail(source, 200).orElseThrow();

    assertEquals(thumbnail, again);
    assertTrue(Files.getLastModifiedTime(again).compareTo(stale) > 0);
  }

  @Test
  void returnsEmptyForNonImagePayload(@TempDir Path dir) throws Exception {
    Path source = Files.writeString(dir.resolve("note.jpg"), "这不是图片");

    assertFalse(cache.thumbnail(source, 200).isPresent());
  }

  @Test
  void returnsEmptyForOutOfRangeSide(@TempDir Path dir) throws Exception {
    Path source = writeJpeg(dir.resolve("photo.jpg"), 400, 300);

    assertFalse(cache.thumbnail(source, ImageThumbnailCache.MIN_SIDE - 1).isPresent());
    assertFalse(cache.thumbnail(source, ImageThumbnailCache.MAX_SIDE + 1).isPresent());
  }

  @Test
  void returnsEmptyForMissingSource(@TempDir Path dir) {
    assertFalse(cache.thumbnail(dir.resolve("absent.jpg"), 200).isPresent());
  }

  private Path writeJpeg(Path path, int width, int height) throws Exception {
    BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = image.createGraphics();
    try {
      // 纯色图会被 JPEG 压到几百字节，用条纹+噪点保证体积有区分度。
      graphics.setColor(Color.WHITE);
      graphics.fillRect(0, 0, width, height);
      for (int x = 0; x < width; x += 7) {
        graphics.setColor((x / 7) % 2 == 0 ? Color.BLACK : new Color(30, 120, 200));
        graphics.drawLine(x, 0, x, height);
      }
    } finally {
      graphics.dispose();
    }
    assertTrue(ImageIO.write(image, "JPEG", path.toFile()));
    return path;
  }
}
