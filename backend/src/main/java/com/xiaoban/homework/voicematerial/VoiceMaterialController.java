package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.auth.AuthInterceptor;
import com.xiaoban.homework.media.MediaAssetService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import java.net.MalformedURLException;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class VoiceMaterialController {
  private final VoiceMaterialService materials;
  private final VoiceMaterialAssignmentService assignments;
  private final MediaAssetService mediaAssets;

  public VoiceMaterialController(VoiceMaterialService materials,
      VoiceMaterialAssignmentService assignments, MediaAssetService mediaAssets) {
    this.materials = materials;
    this.assignments = assignments;
    this.mediaAssets = mediaAssets;
  }

  @PostMapping("/students/{studentId}/voice-material-batches")
  public VoiceMaterialDtos.BatchResponse createBatch(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId) {
    return materials.createBatch(familyId, studentId);
  }

  @PostMapping("/voice-material-batches/{batchId}/packages")
  public VoiceMaterialDtos.PackageResponse registerPackage(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID batchId,
      @Valid @RequestBody VoiceMaterialDtos.RegisterPackageRequest request) {
    return materials.registerPackage(familyId, batchId, request);
  }

  @PostMapping(value = "/voice-material-packages/{packageId}/files",
      consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public VoiceMaterialDtos.FileResponse uploadFile(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID packageId,
      @RequestParam String resourceType,
      @RequestParam(required = false, defaultValue = "") String relativeName,
      @RequestParam(required = false, defaultValue = "0") int sortOrder,
      @RequestPart("file") MultipartFile file) {
    return materials.uploadFile(
        familyId, packageId, resourceType, relativeName, sortOrder, file);
  }

  @PostMapping("/voice-material-batches/{batchId}/complete")
  public VoiceMaterialDtos.BatchResponse completeBatch(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID batchId) {
    return materials.completeBatch(familyId, batchId);
  }

  @GetMapping("/students/{studentId}/voice-material-packages")
  public List<VoiceMaterialDtos.PackageResponse> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId) {
    return materials.list(familyId, studentId);
  }

  @GetMapping("/media-assets/{assetId}")
  public ResponseEntity<Resource> downloadAsset(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID assetId) throws MalformedURLException {
    MediaAssetService.ResolvedAsset file = mediaAssets.resolveOwned(familyId, assetId);
    Resource resource = new UrlResource(file.path().toUri());
    MediaType type;
    try { type = MediaType.parseMediaType(file.contentType()); }
    catch (IllegalArgumentException error) { type = MediaType.APPLICATION_OCTET_STREAM; }
    return ResponseEntity.ok().contentType(type)
        .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline().filename(file.originalName()).build().toString())
        .body(resource);
  }

  @PostMapping("/voice-material-packages/{packageId}/create-assignment")
  public VoiceMaterialDtos.CreateAssignmentResponse createAssignment(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID packageId,
      @Valid @RequestBody VoiceMaterialDtos.CreateAssignmentRequest request) {
    return assignments.createManually(familyId, packageId, request);
  }

  @PostMapping("/students/{studentId}/voice-material-packages/auto-create-next")
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId) {
    return assignments.autoCreateNext(familyId, studentId);
  }
}
