package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import java.io.ByteArrayInputStream;
import java.util.Base64;
import java.util.Locale;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.MemoryCacheImageInputStream;

/** Bounded, in-memory image input. Never accepts external URLs or writes a temporary file. */
final class HomeworkImageInput {
  static final int MAX_BYTES = 4 * 1024 * 1024;
  static final int MAX_BASE64_CHARS = 4 * ((MAX_BYTES + 2) / 3);
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
        if (reader.read(0) == null) throw new ApiExceptions.BadRequest("图片内容不合法");
      } finally {
        reader.dispose();
      }
    } catch (ApiExceptions.BadRequest invalid) {
      throw invalid;
    } catch (Exception invalid) {
      throw new ApiExceptions.BadRequest("图片内容不合法");
    }
    return "data:" + contentType + ";base64," + request.imageBase64();
  }
}
