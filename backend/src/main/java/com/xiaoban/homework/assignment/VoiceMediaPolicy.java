package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Component
public class VoiceMediaPolicy {
  public static final long MAX_AUDIO_BYTES = 20L * 1024 * 1024;
  public static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;
  private static final int SIGNATURE_BYTES = 16;

  public void validateAudio(MultipartFile audio) {
    if (audio == null || audio.isEmpty()) throw new ApiExceptions.BadRequest("请选择一个语音文件");
    if (audio.getSize() > MAX_AUDIO_BYTES) throw new ApiExceptions.BadRequest("语音文件不能超过 20MB");

    String actual = detectAudioKind(prefix(audio));
    if (actual == null) throw new ApiExceptions.BadRequest("语音文件内容不是受支持的 mp3、m4a 或 wav");
    validateDeclaredKind(audio, actual, true);
  }

  public void validateImage(MultipartFile image) {
    if (image == null || image.isEmpty()) throw new ApiExceptions.BadRequest("图片文件不能为空");
    if (image.getSize() > MAX_IMAGE_BYTES) throw new ApiExceptions.BadRequest("单张图片不能超过 5MB");

    String actual = detectImageKind(prefix(image));
    if (actual == null) throw new ApiExceptions.BadRequest("图片文件内容不是受支持的 jpg、png、webp 或 heic");
    validateDeclaredKind(image, actual, false);
  }

  private void validateDeclaredKind(MultipartFile file, String actual, boolean audio) {
    String declared = declaredKind(mediaType(file), audio);
    String extension = extensionKind(fileName(file), audio);
    if (declared == null && extension == null) {
      throw new ApiExceptions.BadRequest(audio
          ? "仅支持 mp3、m4a、wav 语音文件"
          : "仅支持 jpg、png、webp、heic 图片");
    }
    if (declared != null && !declared.equals(actual)) {
      throw new ApiExceptions.BadRequest("媒体文件内容与 Content-Type 不一致");
    }
    if (extension != null && !extension.equals(actual)) {
      throw new ApiExceptions.BadRequest("媒体文件内容与文件扩展名不一致");
    }
  }

  private String declaredKind(String type, boolean audio) {
    if (type.isBlank() || "application/octet-stream".equals(type)) return null;
    if (audio) {
      if ("audio/mpeg".equals(type) || "audio/mp3".equals(type)) return "mp3";
      if ("audio/mp4".equals(type) || "audio/x-m4a".equals(type) || "audio/m4a".equals(type)) return "m4a";
      if ("audio/wav".equals(type) || "audio/x-wav".equals(type) || "audio/wave".equals(type)) return "wav";
      return null;
    }
    if ("image/jpeg".equals(type) || "image/jpg".equals(type)) return "jpeg";
    if ("image/png".equals(type)) return "png";
    if ("image/webp".equals(type)) return "webp";
    if ("image/heic".equals(type) || "image/heif".equals(type)) return "heic";
    return null;
  }

  private String extensionKind(String name, boolean audio) {
    if (audio) {
      if (name.endsWith(".mp3")) return "mp3";
      if (name.endsWith(".m4a")) return "m4a";
      if (name.endsWith(".wav")) return "wav";
      return null;
    }
    if (name.endsWith(".jpg") || name.endsWith(".jpeg")) return "jpeg";
    if (name.endsWith(".png")) return "png";
    if (name.endsWith(".webp")) return "webp";
    if (name.endsWith(".heic") || name.endsWith(".heif")) return "heic";
    return null;
  }

  private String detectImageKind(byte[] value) {
    if (value.length >= 3 &&
        unsigned(value[0]) == 0xff && unsigned(value[1]) == 0xd8 && unsigned(value[2]) == 0xff) {
      return "jpeg";
    }
    if (value.length >= 8 &&
        unsigned(value[0]) == 0x89 && value[1] == 'P' && value[2] == 'N' && value[3] == 'G' &&
        unsigned(value[4]) == 0x0d && unsigned(value[5]) == 0x0a &&
        unsigned(value[6]) == 0x1a && unsigned(value[7]) == 0x0a) {
      return "png";
    }
    if (value.length >= 12 && ascii(value, 0, 4).equals("RIFF") && ascii(value, 8, 4).equals("WEBP")) {
      return "webp";
    }
    if (value.length >= 12 && ascii(value, 4, 4).equals("ftyp")) {
      String brand = ascii(value, 8, 4).toLowerCase(Locale.ROOT);
      if (brand.equals("heic") || brand.equals("heix") || brand.equals("hevc") ||
          brand.equals("hevx") || brand.equals("mif1") || brand.equals("msf1")) {
        return "heic";
      }
    }
    return null;
  }

  private String detectAudioKind(byte[] value) {
    if (value.length >= 12 && ascii(value, 0, 4).equals("RIFF") && ascii(value, 8, 4).equals("WAVE")) {
      return "wav";
    }
    if (value.length >= 3 && ascii(value, 0, 3).equals("ID3")) return "mp3";
    if (value.length >= 2 && unsigned(value[0]) == 0xff && (unsigned(value[1]) & 0xe0) == 0xe0) {
      return "mp3";
    }
    if (value.length >= 12 && ascii(value, 4, 4).equals("ftyp")) {
      String brand = ascii(value, 8, 4).toLowerCase(Locale.ROOT);
      if (brand.equals("m4a ") || brand.equals("m4b ") || brand.equals("isom") ||
          brand.equals("mp41") || brand.equals("mp42") || brand.equals("qt  ")) {
        return "m4a";
      }
    }
    return null;
  }

  private byte[] prefix(MultipartFile file) {
    try (InputStream input = file.getInputStream()) {
      return input.readNBytes(SIGNATURE_BYTES);
    } catch (IOException error) {
      throw new ApiExceptions.BadRequest("无法读取媒体文件");
    }
  }

  private String ascii(byte[] value, int offset, int length) {
    if (value.length < offset + length) return "";
    return new String(value, offset, length, StandardCharsets.US_ASCII);
  }

  private int unsigned(byte value) {
    return value & 0xff;
  }

  private String mediaType(MultipartFile file) {
    String value = file.getContentType();
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }

  private String fileName(MultipartFile file) {
    String value = file.getOriginalFilename();
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }
}
