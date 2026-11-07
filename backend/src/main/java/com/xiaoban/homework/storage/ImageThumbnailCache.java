package com.xiaoban.homework.storage;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Iterator;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 按需生成并缓存图片缩略图。
 *
 * <p>作业照片是手机原图（常见 4160×3120、3MB 左右），而 App 列表里只显示 86vp 的小图，
 * 服务器出口带宽只有约 3Mbps——直接下发原图意味着「看一个缩略图要等 8 秒」。
 * 缩略图按长边生成后落在原图同目录的 {@code .thumbs/} 下，二次请求直接命中磁盘。
 *
 * <p>解码走 {@link ImageReader} + 子采样，13MP 原图不会整块读进内存；子采样后的尺寸
 * 一定不小于目标尺寸，再用双线性缩到精确尺寸，避免锯齿。
 */
@Component
public class ImageThumbnailCache {
  private static final Logger log = LoggerFactory.getLogger(ImageThumbnailCache.class);
  /** 缩略图长边下限/上限，超出范围视为非法参数（直接回退原图）。 */
  public static final int MIN_SIDE = 32;
  public static final int MAX_SIDE = 2048;
  static final String THUMB_DIRECTORY = ".thumbs";
  /** 单张图解码像素上限，超过就不做缩略图（防解码炸弹）。 */
  private static final long MAX_SOURCE_PIXELS = 120_000_000L;
  private static final float QUALITY = 0.8f;
  /** 同一张图同一尺寸只让一个线程解码，其余线程等同一个 Future 的结果。 */
  private static final Map<String, CompletableFuture<Optional<Path>>> IN_FLIGHT = new ConcurrentHashMap<>();
  private static final long RENDER_WAIT_SECONDS = 30L;

  /**
   * @param maxSide 缩略图长边像素上限
   * @return 缩略图文件；源文件不是可解码图片（例如 heic）、或尺寸非法时为 empty
   */
  public Optional<Path> thumbnail(Path source, int maxSide) {
    if (maxSide < MIN_SIDE || maxSide > MAX_SIDE) return Optional.empty();
    if (source == null || !Files.isRegularFile(source)) return Optional.empty();

    Path target = thumbnailPath(source, maxSide);
    if (isFresh(target, source)) return Optional.of(target);

    String key = target.toAbsolutePath().toString();
    // 用同一个 Future 代表「这一轮生成」，所有并发请求等它完成。
    // 旧实现在 finally 里移除锁对象，等待中的线程仍持有旧锁、后到的线程拿到新锁，
    // 于是同图被并发解码两次，去重设计落空。
    CompletableFuture<Optional<Path>> mine = new CompletableFuture<>();
    CompletableFuture<Optional<Path>> owner = IN_FLIGHT.putIfAbsent(key, mine);
    if (owner != null) {
      try {
        return owner.get(RENDER_WAIT_SECONDS, TimeUnit.SECONDS);
      } catch (InterruptedException interrupted) {
        Thread.currentThread().interrupt();
        return Optional.empty();
      } catch (Exception waiting) {
        return isFresh(target, source) ? Optional.of(target) : Optional.empty();
      }
    }
    try {
      Optional<Path> result = isFresh(target, source) ? Optional.of(target) : render(source, target, maxSide);
      mine.complete(result);
      return result;
    } catch (RuntimeException failure) {
      mine.complete(Optional.empty());
      throw failure;
    } finally {
      IN_FLIGHT.remove(key, mine);
    }
  }

  /**
   * 越界的 {@code w} 不该回退下发 3MB 原图（等于把出口带宽放大交给客户端决定），
   * 一律夹到合法档位；非法类型由 ApiExceptionHandler 统一映射为 400。
   */
  public static int clampSide(int requested) {
    return Math.max(MIN_SIDE, Math.min(MAX_SIDE, requested));
  }

  /** 缩略图固定为 JPEG，调用方据此设置 Content-Type。 */
  public static String contentType() {
    return "image/jpeg";
  }

  private Optional<Path> render(Path source, Path target, int maxSide) {
    BufferedImage decoded = null;
    try {
      decoded = readSubsampled(source, maxSide);
      if (decoded == null) return Optional.empty();
      BufferedImage scaled = scaleToMaxSide(decoded, maxSide);
      return writeJpeg(scaled, target) ? Optional.of(target) : Optional.empty();
    } catch (IOException | RuntimeException failure) {
      // 日志规范：不记录源文件/原始文件名，也不输出可能含路径的异常 message。
      log.debug("thumbnail generation skipped reason=DECODE_FAILED exceptionType={}",
          failure.getClass().getSimpleName());
      return Optional.empty();
    } finally {
      if (decoded != null) decoded.flush();
    }
  }

  private BufferedImage readSubsampled(Path source, int maxSide) throws IOException {
    try (ImageInputStream input = ImageIO.createImageInputStream(source.toFile())) {
      if (input == null) return null;
      Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) return null;
      ImageReader reader = readers.next();
      try {
        reader.setInput(input, true, true);
        int width = reader.getWidth(0);
        int height = reader.getHeight(0);
        if (width <= 0 || height <= 0 || (long) width * height > MAX_SOURCE_PIXELS) return null;

        int longest = Math.max(width, height);
        // 子采样后仍要不小于目标尺寸，否则细节已经被丢掉，再插值放大也没意义。
        int sample = Math.max(1, longest / Math.max(1, maxSide));
        ImageReadParam param = reader.getDefaultReadParam();
        if (sample > 1) {
          param.setSourceSubsampling(sample, sample, 0, 0);
        }
        return reader.read(0, param);
      } finally {
        reader.dispose();
      }
    }
  }

  private BufferedImage scaleToMaxSide(BufferedImage image, int maxSide) {
    int width = image.getWidth();
    int height = image.getHeight();
    int longest = Math.max(width, height);
    if (longest <= maxSide) return image;

    double ratio = (double) maxSide / longest;
    int targetWidth = Math.max(1, (int) Math.round(width * ratio));
    int targetHeight = Math.max(1, (int) Math.round(height * ratio));
    BufferedImage scaled = new BufferedImage(targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = scaled.createGraphics();
    try {
      graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
      graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
      graphics.drawImage(image, 0, 0, targetWidth, targetHeight, null);
    } finally {
      graphics.dispose();
    }
    return scaled;
  }

  private boolean writeJpeg(BufferedImage image, Path target) throws IOException {
    Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpeg");
    if (!writers.hasNext()) return false;
    ImageWriter writer = writers.next();
    Files.createDirectories(target.getParent());
    // 先写临时文件再原子改名：半个缩略图比没有缩略图更糟（会被 isFresh 当成有效缓存）。
    Path temp = Files.createTempFile(target.getParent(), "thumb-", ".part");
    try {
      try (OutputStream out = Files.newOutputStream(temp);
           ImageOutputStream imageOut = ImageIO.createImageOutputStream(out)) {
        writer.setOutput(imageOut);
        ImageWriteParam param = writer.getDefaultWriteParam();
        param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
        param.setCompressionQuality(QUALITY);
        writer.write(null, new IIOImage(image, null, null), param);
      }
      moveIntoPlace(temp, target);
      return true;
    } finally {
      writer.dispose();
      try {
        Files.deleteIfExists(temp);
      } catch (IOException ignored) {
        // 残留的 .part 不会命中缓存，下次生成时会被覆盖。
      }
    }
  }

  private void moveIntoPlace(Path temp, Path target) {
    try {
      Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    } catch (AtomicMoveNotSupportedException unsupported) {
      // 某些容器文件系统不支持原子改名，退化成普通替换。
      try {
        Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
      } catch (IOException failure) {
        throw new IllegalStateException("缩略图写入失败", failure);
      }
    } catch (IOException failure) {
      throw new IllegalStateException("缩略图写入失败", failure);
    }
  }

  /**
   * 缩略图比源图新（或同时间戳）就命中。源图被覆盖写时不能只靠 mtime 判断——
   * 秒级精度文件系统上新旧文件可能落在同一时间戳，所以 {@code LocalFileStorage.save}
   * 会在覆盖前主动删除该源图的所有派生物。
   */
  private boolean isFresh(Path thumbnail, Path source) {
    try {
      if (!Files.isRegularFile(thumbnail) || Files.size(thumbnail) <= 0) return false;
      return Files.getLastModifiedTime(thumbnail).compareTo(Files.getLastModifiedTime(source)) >= 0;
    } catch (IOException missing) {
      return false;
    }
  }

  private Path thumbnailPath(Path source, int maxSide) {
    Path parent = source.getParent() == null ? Path.of(".") : source.getParent();
    String name = source.getFileName().toString();
    String base = name;
    int dot = name.lastIndexOf('.');
    if (dot > 0) base = name.substring(0, dot);
    return parent.resolve(THUMB_DIRECTORY).resolve(base + "-w" + maxSide + ".jpg");
  }
}
