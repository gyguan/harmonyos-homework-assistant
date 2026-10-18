package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.Locale;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.MemoryCacheImageInputStream;

/** Bounded, in-memory image input. Never accepts external URLs or writes a temporary file. */
final class HomeworkImageInput {
  static final int MAX_BYTES = 4 * 1024 * 1024;
  static final int MAX_BASE64_CHARS = 4 * ((MAX_BYTES + 2) / 3);

  /**
   * 送给视觉模型的图片长边上限。
   *
   * 视觉 token 数与像素数成正比，而预填充阶段全部花在等待上：同一张黑板图实测
   * 首 token 延迟 2048px≈22.6 秒、1536px≈5.3 秒、1280px≈11.8 秒（免费档有抖动，
   * 但 2048 明显更慢）。作业照片里的字一般在 1536px 下仍然清晰可辨，
   * 再往下压识别率会掉，所以统一收到 1536。
   */
  static final int MAX_SIDE = 1536;

  private HomeworkImageInput() {}

  static String dataUrl(HomeworkOrganizerDtos.ImageRequest request) {
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
    try (var input = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
      var readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) throw new ApiExceptions.BadRequest("图片格式不合法");
      ImageReader reader = readers.next();
      try {
        if (!expectedFormat.equalsIgnoreCase(reader.getFormatName())) {
          throw new ApiExceptions.BadRequest("图片格式与声明不一致");
        }
        reader.setInput(input, true, true);
        int width = reader.getWidth(0);
        int height = reader.getHeight(0);
        if (width <= 0 || height <= 0 || (long) width * height > 40_000_000L) {
          throw new ApiExceptions.BadRequest("图片尺寸过大，请缩小后重试");
        }
        // Decode after dimension checks so a truncated or malformed image cannot reach the provider.
        BufferedImage decoded = reader.read(0);
        if (decoded == null) throw new ApiExceptions.BadRequest("图片内容不合法");
        byte[] shrunk = shrinkToMaxSide(decoded);
        if (shrunk != null) {
          payload = shrunk;
          payloadType = "image/jpeg";
        }
      } finally {
        reader.dispose();
      }
    } catch (ApiExceptions.BadRequest invalid) {
      throw invalid;
    } catch (Exception invalid) {
      throw new ApiExceptions.BadRequest("图片内容不合法");
    }
    return "data:" + payloadType + ";base64," + Base64.getEncoder().encodeToString(payload);
  }

  /**
   * 把超过 {@link #MAX_SIDE} 的图缩到长边 {@link #MAX_SIDE} 并重编码为 JPEG。
   * 返回 null 表示不需要缩放（保持原始字节，避免一次无谓的有损重编码）。
   */
  static byte[] shrinkToMaxSide(BufferedImage image) {
    int width = image.getWidth();
    int height = image.getHeight();
    if (width <= 0 || height <= 0) return null;
    int longest = Math.max(width, height);
    if (longest <= MAX_SIDE) return null;

    double ratio = (double) MAX_SIDE / longest;
    int targetWidth = Math.max(1, (int) Math.round(width * ratio));
    int targetHeight = Math.max(1, (int) Math.round(height * ratio));
    BufferedImage scaled = new BufferedImage(targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = scaled.createGraphics();
    try {
      graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
      graphics.drawImage(image, 0, 0, targetWidth, targetHeight, null);
    } finally {
      graphics.dispose();
    }
    try (var output = new ByteArrayOutputStream()) {
      if (!ImageIO.write(scaled, "JPEG", output)) return null;
      return output.toByteArray();
    } catch (IOException unwritable) {
      return null;
    }
  }
}
