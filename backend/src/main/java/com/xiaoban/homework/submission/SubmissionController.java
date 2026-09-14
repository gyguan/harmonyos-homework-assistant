package com.xiaoban.homework.submission;

import com.xiaoban.homework.auth.AuthInterceptor;
import java.net.MalformedURLException;
import java.util.List;
import java.util.UUID;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class SubmissionController {
  private final SubmissionService service;
  public SubmissionController(SubmissionService service) { this.service = service; }

  @PostMapping(value = "/assignments/{assignmentId}/submissions", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public SubmissionDtos.Response create(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId, @RequestPart("photos") List<MultipartFile> photos) {
    return service.create(familyId, assignmentId, photos);
  }

  @GetMapping("/assignments/{assignmentId}/submissions")
  public List<SubmissionDtos.Response> list(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) { return service.list(familyId, assignmentId); }

  @GetMapping("/submission-photos/{photoId}")
  public ResponseEntity<Resource> photo(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID photoId) throws MalformedURLException {
    SubmissionService.PhotoDownload file = service.photo(familyId, photoId);
    Resource resource = new UrlResource(file.path().toUri());
    return ResponseEntity.ok().contentType(MediaType.parseMediaType(file.contentType()))
        .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline().filename(file.originalName()).build().toString())
        .body(resource);
  }
}
