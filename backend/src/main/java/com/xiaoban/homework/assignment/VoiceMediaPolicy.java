package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import java.util.Locale;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Component
public class VoiceMediaPolicy {
  public static final long MAX_AUDIO_BYTES = 20L * 1024 * 1024;
  public static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;

  public void validateAudio(MultipartFile audio) {
    if (audio == null || audio.isEmpty()) throw new ApiExceptions.BadRequest("请选择一个语音文件");
    if (audio.getSize() > MAX_AUDIO_BYTES) throw new ApiExceptions.BadRequest("语音文件不能超过 20MB");
    String type = mediaType(audio);
    String name = fileName(audio);
    boolean supported = type.equals("audio/mpeg") || type.equals("audio/mp4") ||
        type.equals("audio/x-m4a") || type.equals("audio/wav") || type.equals("audio/x-wav") ||
        name.endsWith(".mp3") || name.endsWith(".m4a") || name.endsWith(".wav");
    if (!supported) throw new ApiExceptions.BadRequest("仅支持 mp3、m4a、wav 语音文件");
  }

  public void validateImage(MultipartFile image) {
    if (image == null || image.isEmpty()) throw new ApiExceptions.BadRequest("图片文件不能为空");
    if (image.getSize() > MAX_IMAGE_BYTES) throw new ApiExceptions.BadRequest("单张图片不能超过 5MB");
    String type = mediaType(image);
    String name = fileName(image);
    boolean supported = type.equals("image/jpeg") || type.equals("image/png") ||
        type.equals("image/webp") || type.equals("image/heic") ||
        name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png") ||
        name.endsWith(".webp") || name.endsWith(".heic");
    if (!supported) throw new ApiExceptions.BadRequest("仅支持 jpg、png、webp、heic 图片");
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
