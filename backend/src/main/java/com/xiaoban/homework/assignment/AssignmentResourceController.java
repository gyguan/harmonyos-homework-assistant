package com.xiaoban.homework.assignment;

import com.xiaoban.homework.auth.AuthInterceptor;
import com.xiaoban.homework.storage.ImageThumbnailCache;
import jakarta.validation.Valid;
import java.net.MalformedURLException;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class AssignmentResourceController {
  /** 作业附件可以被删除后重传，缓存别放太久。 */
  private static final Duration RESOURCE_MAX_AGE = Duration.ofHours(12);

  private final AssignmentResourceService service;
  private final ImageThumbnailCache thumbnails;

  public AssignmentResourceController(AssignmentResourceService service,
      ImageThumbnailCache thumbnails) {
    this.service = service;
    this.thumbnails = thumbnails;
  }

  @PostMapping(value = "/students/{studentId}/assignments/voice",
      consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public AssignmentResourceDtos.VoiceCreateResponse createVoice(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestPart("metadata") AssignmentDtos.Create metadata,
      @RequestPart("audio") MultipartFile audio,
      @RequestPart("images") List<MultipartFile> images) {
    return service.createVoiceAssignment(familyId, studentId, metadata, audio, images);
  }

  @PostMapping(value = "/assignments/{assignmentId}/resources", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public AssignmentResourceDtos.Response addResource(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId, @RequestPart("file") MultipartFile file) {
    return service.addResource(familyId, assignmentId, file);
  }

  @DeleteMapping("/assignments/{assignmentId}/resources/{resourceId}")
  public void removeResource(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId, @PathVariable UUID resourceId) {
    service.removeResource(familyId, assignmentId, resourceId);
  }

  @GetMapping("/assignments/{assignmentId}/resources")
  public List<AssignmentResourceDtos.Response> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) {
    return service.list(familyId, assignmentId);
  }

  /** @param width 可选，缩略图长边像素上限；列表/轮播只要小图，别拉原图。 */
  @GetMapping("/assignment-resources/{resourceId}")
  public ResponseEntity<Resource> download(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID resourceId,
      @RequestParam(name = "w", required = false) Integer width) throws MalformedURLException {
    AssignmentResourceService.ResourceDownload file = service.download(familyId, resourceId);
    Path thumbnail = width == null ? null : thumbnails.thumbnail(file.path(), ImageThumbnailCache.clampSide(width)).orElse(null);
    boolean thumb = thumbnail != null;
    MediaType type;
    if (thumb) {
      type = MediaType.IMAGE_JPEG;
    } else {
      try {
        type = MediaType.parseMediaType(file.contentType());
      } catch (IllegalArgumentException error) {
        type = MediaType.APPLICATION_OCTET_STREAM;
      }
    }
    return ResponseEntity.ok()
        .contentType(type)
        .header(HttpHeaders.CONTENT_DISPOSITION,
            ContentDisposition.inline().filename(file.originalName()).build().toString())
        .cacheControl(CacheControl.maxAge(RESOURCE_MAX_AGE).cachePrivate())
        .body(new UrlResource((thumb ? thumbnail : file.path()).toUri()));
  }
}
