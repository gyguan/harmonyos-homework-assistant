package com.xiaoban.homework.assignment;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
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
public class AssignmentResourceController {
  private final AssignmentResourceService service;

  public AssignmentResourceController(AssignmentResourceService service) {
    this.service = service;
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

  @GetMapping("/assignments/{assignmentId}/resources")
  public List<AssignmentResourceDtos.Response> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) {
    return service.list(familyId, assignmentId);
  }

  @GetMapping("/assignment-resources/{resourceId}")
  public ResponseEntity<Resource> download(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID resourceId) throws MalformedURLException {
    AssignmentResourceService.ResourceDownload file = service.download(familyId, resourceId);
    Resource resource = new UrlResource(file.path().toUri());
    MediaType type;
    try {
      type = MediaType.parseMediaType(file.contentType());
    } catch (IllegalArgumentException error) {
      type = MediaType.APPLICATION_OCTET_STREAM;
    }
    return ResponseEntity.ok()
        .contentType(type)
        .header(HttpHeaders.CONTENT_DISPOSITION,
            ContentDisposition.inline().filename(file.originalName()).build().toString())
        .body(resource);
  }
}
