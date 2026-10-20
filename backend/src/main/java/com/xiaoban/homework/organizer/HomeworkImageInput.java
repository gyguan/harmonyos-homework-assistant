package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.MessageDigest;
import java.util.HexFormat;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import java.util.Base64;
import java.util.Locale;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.MemoryCacheImageInputStream;

/** Bounded, in-memory image input. Never accepts external URLs or writes a temporary file. */
final class HomeworkImageInput {
  static final int MAX_BYTES = 4 * 1024 * 1024;
  static final int MAX_BASE64_CHARS = 4 * ((MAX_BYTES + 2) / 3);

  static final String PROCESSING_VERSION = "orientation-v1";
  record Prepared(String dataUrl, String originalHash, int width, int height, int outputWidth,
      int outputHeight, int orientation, int inputBytes, int outputBytes) {}

  private HomeworkImageInput() {}

  static String dataUrl(HomeworkOrganizerDtos.ImageRequest request) { return prepare(request).dataUrl(); }

  static Prepared prepare(HomeworkOrganizerDtos.ImageRequest request) {
    if (request.imageBase64() == null || request.imageBase64().isBlank()
        || request.imageBase64().length() > MAX_BASE64_CHARS) {
      throw new ApiExceptions.BadRequest("图片不能为空且不得超过4MB");
    }
    String contentType = request.contentType() == null ? "" : request.contentType().toLowerCase(Locale.ROOT);
    String expectedFormat = switch (contentType) {
      case "image/jpeg" -> "JPEG";
      case "image/png" -> "PNG";
      default -> throw new ApiExceptions.BadRequest("仅支持JPEG或PNG图片");
    };
    byte[] bytes;
    try {
      bytes = Base64.getDecoder().decode(request.imageBase64());
    } catch (IllegalArgumentException invalid) {
      throw new ApiExceptions.BadRequest("图片编码不合法");
    }
    if (bytes.length == 0 || bytes.length > MAX_BYTES) throw new ApiExceptions.BadRequest("图片不得超过4MB");
    byte[] payload = bytes;
    String payloadType = contentType;
    int width, height, orientation;
    try (var input = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
      var readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) throw new ApiExceptions.BadRequest("图片格式不合法");
      ImageReader reader = readers.next();
      try {
        if (!expectedFormat.equalsIgnoreCase(reader.getFormatName())) {
          throw new ApiExceptions.BadRequest("图片格式与声明不一致");
        }
        reader.setInput(input, true, true);
        width = reader.getWidth(0);
        height = reader.getHeight(0);
        if (width <= 0 || height <= 0 || (long) width * height > 40_000_000L) {
          throw new ApiExceptions.BadRequest("图片尺寸过大，请缩小后重试");
        }
        // Decode after dimension checks so a truncated or malformed image cannot reach the provider.
        BufferedImage decoded = reader.read(0);
        if (decoded == null) throw new ApiExceptions.BadRequest("图片内容不合法");
        orientation = HomeworkImageOrientation.read(bytes, contentType);
        if (orientation != 1) {
          var upright = HomeworkImageOrientation.upright(decoded, orientation);
          try { payload = encodePng(upright, MAX_BYTES); }
          finally { upright.flush(); }
          payloadType = "image/png";
        }
        decoded.flush();
      } finally {
        reader.dispose();
      }
    } catch (ApiExceptions.BadRequest invalid) {
      throw invalid;
    } catch (Exception invalid) {
      throw new ApiExceptions.BadRequest("图片内容不合法");
    }
    String originalHash;
    try { originalHash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)); }
    catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    return new Prepared("data:" + payloadType + ";base64," + Base64.getEncoder().encodeToString(payload),
        originalHash, width, height, orientation >= 5 ? height : width, orientation >= 5 ? width : height,
        orientation, bytes.length, payload.length);
  }

  /** Explicit memory-only output with a hard limit before a cache buffer can grow past it. */
  static byte[] encodePng(BufferedImage image, int limit) {
    var bytes = new ByteArrayOutputStream();
    try (var output = new MemoryCacheImageOutputStream(bytes) {
      private void budget(int count) throws IOException {
        if (count < 0 || getStreamPosition() > (long) limit - count) throw new BudgetExceeded();
      }
      @Override public void write(int value) throws IOException { budget(1); super.write(value); }
      @Override public void write(byte[] buffer, int offset, int length) throws IOException {
        budget(length); super.write(buffer, offset, length);
      }
      @Override public void seek(long position) throws IOException {
        if (position > limit) throw new BudgetExceeded(); super.seek(position);
      }
    }) {
      if (!ImageIO.write(image, "PNG", output)) throw new IOException("PNG writer unavailable");
      output.flush();
      return bytes.toByteArray();
    } catch (IOException failure) {
      for (Throwable cause = failure; cause != null; cause = cause.getCause())
        if (cause instanceof BudgetExceeded) throw new ApiExceptions.BadRequest("图片方向校正后超过4MB，请裁剪所需区域后重试");
      throw new ApiExceptions.BadRequest("图片方向校正失败，请重新导出图片后重试");
    }
  }
  private static final class BudgetExceeded extends IOException {}
}
