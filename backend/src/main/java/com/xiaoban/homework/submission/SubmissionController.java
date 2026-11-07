package com.xiaoban.homework.submission;

import com.xiaoban.homework.auth.AuthInterceptor;
import com.xiaoban.homework.storage.ImageThumbnailCache;
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
public class SubmissionController {
  /** 提交资源按 id 不可变（重新提交会产生新 id），可以放心长缓存。 */
  private static final Duration RESOURCE_MAX_AGE = Duration.ofDays(7);

  private final SubmissionService service;
  private final ImageThumbnailCache thumbnails;

  public SubmissionController(SubmissionService service, ImageThumbnailCache thumbnails) {
    this.service = service;
    this.thumbnails = thumbnails;
  }

  @PostMapping(value = "/assignments/{assignmentId}/submissions", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public SubmissionDtos.CreateResponse create(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId,
      @RequestParam long version,
      @RequestParam(defaultValue = "0") long audioDurationMs,
      @RequestPart(value = "photos", required = false) List<MultipartFile> photos,
      @RequestPart(value = "audio", required = false) MultipartFile audio) {
    return service.create(familyId, assignmentId, version, photos, audio, audioDurationMs);
  }

  @GetMapping("/assignments/{assignmentId}/submissions")
  public List<SubmissionDtos.Response> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) {
    return service.list(familyId, assignmentId);
  }

  @GetMapping("/assignments/{assignmentId}/submissions/latest")
  public ResponseEntity<SubmissionDtos.Response> latest(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) {
    SubmissionDtos.Response latest = service.latest(familyId, assignmentId);
    return latest == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(latest);
  }

  /**
   * @param width 可选，缩略图长边像素上限。列表页只需要 86vp 的小图，拉原图要 8 秒
   *              （服务器出口约 3Mbps，一张原图 3MB），带 w 时下发缩略图（约 20KB）。
   */
  @GetMapping("/submission-resources/{resourceId}")
  public ResponseEntity<Resource> resource(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID resourceId,
      @RequestParam(name = "w", required = false) Integer width) throws MalformedURLException {
    return deliver(service.resource(familyId, resourceId, null), width);
  }

  /**
   * Legacy photo route retained for older app versions while submission resources migrate
   * from photo-only storage to a generic resource model.
   */
  @GetMapping("/submission-photos/{photoId}")
  public ResponseEntity<Resource> photo(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID photoId,
      @RequestParam(name = "w", required = false) Integer width) throws MalformedURLException {
    return deliver(service.resource(familyId, photoId, "IMAGE"), width);
  }

  private ResponseEntity<Resource> deliver(SubmissionService.ResourceDownload file, Integer width)
      throws MalformedURLException {
    Path thumbnail = width == null ? null : thumbnails.thumbnail(file.path(), ImageThumbnailCache.clampSide(width)).orElse(null);
    boolean thumb = thumbnail != null;
    String contentType = thumb ? ImageThumbnailCache.contentType() : file.contentType();
    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(contentType))
        .header(HttpHeaders.CONTENT_DISPOSITION,
            ContentDisposition.inline().filename(file.originalName()).build().toString())
        .cacheControl(CacheControl.maxAge(RESOURCE_MAX_AGE).cachePrivate())
        .body(new UrlResource((thumb ? thumbnail : file.path()).toUri()));
  }
}
