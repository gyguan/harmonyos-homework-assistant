package com.xiaoban.homework.mediasync;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.xiaoban.homework.assignment.AssignmentResourceEntity;
import com.xiaoban.homework.assignment.AssignmentResourceRepository;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.media.MediaAssetEntity;
import com.xiaoban.homework.media.MediaAssetRepository;
import com.xiaoban.homework.storage.FileStorage;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigInteger;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentMediaSyncService {
  private static final Logger log = LoggerFactory.getLogger(AssignmentMediaSyncService.class);
  private static final int SYNC_VERSION = 1;
  private static final int MAX_ATTEMPTS = 2;
  private static final long RETRY_DELAY_SECONDS = 30;

  private final AssignmentMediaSyncRepository syncs;
  private final AssignmentResourceRepository resources;
  private final MediaAssetRepository mediaAssets;
  private final FileStorage storage;
  private final AssignmentService assignments;
  private final ObjectMapper mapper;

  public AssignmentMediaSyncService(AssignmentMediaSyncRepository syncs,
      AssignmentResourceRepository resources, MediaAssetRepository mediaAssets,
      FileStorage storage, AssignmentService assignments, ObjectMapper mapper) {
    this.syncs = syncs;
    this.resources = resources;
    this.mediaAssets = mediaAssets;
    this.storage = storage;
    this.assignments = assignments;
    this.mapper = mapper;
  }

  @Transactional
  public AssignmentMediaSyncEntity ensureMediaSyncJob(UUID familyId, String assignmentId) {
    AssignmentMediaSyncEntity existing =
        syncs.findByFamilyIdAndAssignmentId(familyId, assignmentId).orElse(null);
    if (existing != null) return existing;

    List<AssignmentResourceEntity> assignmentResources =
        resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(familyId, assignmentId);
    AssignmentResourceEntity audio = firstAudio(assignmentResources);
    List<AssignmentResourceEntity> images = orderedImages(assignmentResources);
    if (audio == null || images.isEmpty()) {
      log.info("media_sync job_skipped assignmentId={} reason=MEDIA_INCOMPLETE audioPresent={} imageCount={}",
          assignmentId, audio != null, images.size());
      return null;
    }

    String fingerprint = mediaFingerprint(familyId, audio, images);
    Instant now = Instant.now();
    AssignmentMediaSyncEntity reusable =
        syncs.findFirstByFamilyIdAndMediaFingerprintAndStatusOrderByFinishedAtDesc(
            familyId, fingerprint, "READY").orElse(null);
    if (reusable != null) {
      AssignmentMediaSyncDtos.Timeline remapped = remapTimeline(reusable.timelineJson, images);
      if (remapped != null) {
        AssignmentMediaSyncEntity copied = newSync(familyId, assignmentId, fingerprint, audio.id, now);
        copied.status = "READY";
        copied.audioDurationMs = reusable.audioDurationMs;
        copied.confidence = reusable.confidence;
        copied.timelineJson = toJson(remapped);
        copied.analysisModel = reusable.analysisModel;
        copied.transcriptionModel = reusable.transcriptionModel;
        copied.finishedAt = now;
        copied.nextRetryAt = now;
        AssignmentMediaSyncEntity saved = syncs.saveAndFlush(copied);
        log.info("media_sync reused assignmentId={} sourceAssignmentId={} fingerprint={} imageCount={} analysisModel={}",
            assignmentId, reusable.assignmentId, fingerprint, images.size(), copied.analysisModel);
        return saved;
      }
    }

    AssignmentMediaSyncEntity pending = newSync(familyId, assignmentId, fingerprint, audio.id, now);
    AssignmentMediaSyncEntity saved = syncs.saveAndFlush(pending);
    log.info("media_sync job_created assignmentId={} syncId={} fingerprint={} imageCount={} status=PENDING",
        assignmentId, saved.id, fingerprint, images.size());
    return saved;
  }

  @Transactional
  public AssignmentMediaSyncDtos.Response get(UUID familyId, String assignmentId) {
    assignments.requireOwned(familyId, assignmentId);
    AssignmentMediaSyncEntity sync =
        syncs.findByFamilyIdAndAssignmentId(familyId, assignmentId).orElse(null);
    if (sync == null) sync = ensureMediaSyncJob(familyId, assignmentId);
    if (sync == null) return AssignmentMediaSyncDtos.Response.unavailable("UNAVAILABLE");
    if (!"READY".equals(sync.status)) return AssignmentMediaSyncDtos.Response.unavailable(sync.status);

    try {
      AssignmentMediaSyncDtos.Timeline timeline =
          mapper.readValue(sync.timelineJson, AssignmentMediaSyncDtos.Timeline.class);
      return new AssignmentMediaSyncDtos.Response(
          "READY", true, timeline.confidence(), timeline.durationMs(), timeline.items());
    } catch (JsonProcessingException error) {
      log.warn("media_sync response_parse_failed assignmentId={} syncId={} message={}",
          assignmentId, sync.id, error.getMessage());
      return AssignmentMediaSyncDtos.Response.unavailable("FAILED");
    }
  }

  @Transactional(readOnly = true)
  public List<UUID> dueJobIds(Instant now) {
    return syncs.findTop2ByStatusAndNextRetryAtLessThanEqualOrderByCreatedAtAsc("PENDING", now)
        .stream().map(item -> item.id).toList();
  }

  @Transactional
  public int recoverStaleRunning(Instant staleBefore, Instant now) {
    int recovered = 0;
    for (AssignmentMediaSyncEntity item :
        syncs.findTop10ByStatusAndStartedAtBeforeOrderByStartedAtAsc("RUNNING", staleBefore)) {
      item.status = "PENDING";
      item.nextRetryAt = now;
      item.errorCode = "WORKER_RECOVERED";
      item.errorMessage = "后台任务中断，已重新排队";
      item.updatedAt = now;
      syncs.save(item);
      recovered++;
      log.warn("media_sync recovered assignmentId={} syncId={} attemptCount={}",
          item.assignmentId, item.id, item.attemptCount);
    }
    if (recovered > 0) syncs.flush();
    return recovered;
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public boolean claim(UUID syncId, Instant now) {
    AssignmentMediaSyncEntity item = syncs.findById(syncId).orElse(null);
    if (item == null || !"PENDING".equals(item.status)) return false;
    if (item.nextRetryAt != null && item.nextRetryAt.isAfter(now)) return false;

    item.status = "RUNNING";
    item.attemptCount++;
    item.startedAt = now;
    item.updatedAt = now;
    item.errorCode = "";
    item.errorMessage = "";
    syncs.saveAndFlush(item);
    log.info("media_sync analysis_started assignmentId={} syncId={} attemptCount={}",
        item.assignmentId, item.id, item.attemptCount);
    return true;
  }

  @Transactional(readOnly = true)
  public TimelineBuildResult buildStubTimeline(UUID syncId) {
    AssignmentMediaSyncEntity item = syncs.findById(syncId)
        .orElseThrow(() -> new IllegalStateException("图文同步任务不存在"));
    List<AssignmentResourceEntity> assignmentResources =
        resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
            item.familyId, item.assignmentId);
    AssignmentResourceEntity audio = firstAudio(assignmentResources);
    List<AssignmentResourceEntity> images = orderedImages(assignmentResources);
    if (audio == null || images.isEmpty()) throw new IllegalStateException("语音作业资料不完整");

    List<AssignmentMediaSyncDtos.Item> timelineItems = new ArrayList<>();
    for (AssignmentResourceEntity image : images) {
      timelineItems.add(new AssignmentMediaSyncDtos.Item(image.id.toString(), 0, 0, 0.25));
    }
    AssignmentMediaSyncDtos.Timeline timeline =
        new AssignmentMediaSyncDtos.Timeline(SYNC_VERSION, 0, 0.25, timelineItems);
    return new TimelineBuildResult(audio.id, 0, 0.25, toJson(timeline), "STUB_EQUAL", "");
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void complete(UUID syncId, TimelineBuildResult result, Instant now) {
    AssignmentMediaSyncEntity item = syncs.findById(syncId)
        .orElseThrow(() -> new IllegalStateException("图文同步任务不存在"));
    if (!"RUNNING".equals(item.status)) return;

    item.status = "READY";
    item.audioResourceId = result.audioResourceId();
    item.audioDurationMs = result.audioDurationMs();
    item.confidence = result.confidence();
    item.timelineJson = result.timelineJson();
    item.analysisModel = result.analysisModel();
    item.transcriptionModel = result.transcriptionModel();
    item.nextRetryAt = now;
    item.errorCode = "";
    item.errorMessage = "";
    item.finishedAt = now;
    item.updatedAt = now;
    syncs.saveAndFlush(item);
    log.info("media_sync alignment_completed assignmentId={} syncId={} alignmentMethod={} confidence={}",
        item.assignmentId, item.id, result.analysisModel(), result.confidence());
    log.info("media_sync ready assignmentId={} syncId={} audioDurationMs={} analysisModel={} attemptCount={}",
        item.assignmentId, item.id, item.audioDurationMs, item.analysisModel, item.attemptCount);
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void fail(UUID syncId, Instant now, RuntimeException error) {
    AssignmentMediaSyncEntity item = syncs.findById(syncId).orElse(null);
    if (item == null) return;

    String message = error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage();
    item.errorCode = truncate(error.getClass().getSimpleName(), 80);
    item.errorMessage = truncate(message, 500);
    item.updatedAt = now;
    item.startedAt = null;

    boolean retry = item.attemptCount < MAX_ATTEMPTS;
    if (retry) {
      item.status = "PENDING";
      item.nextRetryAt = now.plus(RETRY_DELAY_SECONDS, ChronoUnit.SECONDS);
      item.finishedAt = null;
    } else {
      item.status = "FAILED";
      item.nextRetryAt = now;
      item.finishedAt = now;
    }
    syncs.saveAndFlush(item);
    log.warn("media_sync failed assignmentId={} syncId={} attemptCount={} retryScheduled={} errorCode={} message={}",
        item.assignmentId, item.id, item.attemptCount, retry, item.errorCode, item.errorMessage);
  }

  private AssignmentMediaSyncEntity newSync(UUID familyId, String assignmentId,
      String fingerprint, UUID audioResourceId, Instant now) {
    AssignmentMediaSyncEntity item = new AssignmentMediaSyncEntity();
    item.id = UUID.randomUUID();
    item.familyId = familyId;
    item.assignmentId = assignmentId;
    item.mediaFingerprint = fingerprint;
    item.status = "PENDING";
    item.syncVersion = SYNC_VERSION;
    item.audioResourceId = audioResourceId;
    item.audioDurationMs = 0;
    item.confidence = 0;
    item.timelineJson = toJson(new AssignmentMediaSyncDtos.Timeline(SYNC_VERSION, 0, 0, List.of()));
    item.analysisModel = "";
    item.transcriptionModel = "";
    item.attemptCount = 0;
    item.nextRetryAt = now;
    item.errorCode = "";
    item.errorMessage = "";
    item.startedAt = null;
    item.finishedAt = null;
    item.createdAt = now;
    item.updatedAt = now;
    return item;
  }

  private AssignmentResourceEntity firstAudio(List<AssignmentResourceEntity> assignmentResources) {
    for (AssignmentResourceEntity resource : assignmentResources) {
      if ("AUDIO".equals(resource.resourceType)) return resource;
    }
    return null;
  }

  private List<AssignmentResourceEntity> orderedImages(List<AssignmentResourceEntity> assignmentResources) {
    return assignmentResources.stream()
        .filter(item -> "IMAGE".equals(item.resourceType))
        .sorted(this::compareImageResources)
        .toList();
  }

  private int compareImageResources(AssignmentResourceEntity left, AssignmentResourceEntity right) {
    int nameCompare = naturalCompare(
        text(left.originalName).toLowerCase(Locale.ROOT),
        text(right.originalName).toLowerCase(Locale.ROOT));
    if (nameCompare != 0) return nameCompare;
    return Integer.compare(left.sortOrder, right.sortOrder);
  }

  private int naturalCompare(String left, String right) {
    int li = 0;
    int ri = 0;
    while (li < left.length() && ri < right.length()) {
      char lc = left.charAt(li);
      char rc = right.charAt(ri);
      if (Character.isDigit(lc) && Character.isDigit(rc)) {
        int le = li;
        int re = ri;
        while (le < left.length() && Character.isDigit(left.charAt(le))) le++;
        while (re < right.length() && Character.isDigit(right.charAt(re))) re++;
        BigInteger ln = new BigInteger(left.substring(li, le));
        BigInteger rn = new BigInteger(right.substring(ri, re));
        int numeric = ln.compareTo(rn);
        if (numeric != 0) return numeric;
        li = le;
        ri = re;
        continue;
      }
      if (lc != rc) return Character.compare(lc, rc);
      li++;
      ri++;
    }
    return Integer.compare(left.length(), right.length());
  }

  private String mediaFingerprint(UUID familyId, AssignmentResourceEntity audio,
      List<AssignmentResourceEntity> images) {
    StringBuilder canonical = new StringBuilder("v1\n");
    canonical.append("audio:").append(resourceHash(familyId, audio)).append('\n');
    for (AssignmentResourceEntity image : images) {
      canonical.append("image:").append(resourceHash(familyId, image)).append('\n');
    }
    return sha256(canonical.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
  }

  private String resourceHash(UUID familyId, AssignmentResourceEntity resource) {
    if (resource.assetId != null) {
      MediaAssetEntity asset = mediaAssets.findById(resource.assetId)
          .orElseThrow(() -> new IllegalStateException("媒体资源不存在"));
      if (!familyId.equals(asset.familyId)) throw new IllegalStateException("媒体资源家庭归属不匹配");
      return asset.sha256 + ":" + asset.sizeBytes;
    }
    if (resource.storagePath == null || resource.storagePath.isBlank()) {
      throw new IllegalStateException("媒体资源存储位置为空");
    }
    Path path = storage.resolve(resource.storagePath);
    try (InputStream input = Files.newInputStream(path)) {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      byte[] buffer = new byte[64 * 1024];
      int read;
      while ((read = input.read(buffer)) >= 0) {
        if (read > 0) digest.update(buffer, 0, read);
      }
      return HexFormat.of().formatHex(digest.digest()) + ":" + resource.sizeBytes;
    } catch (IOException | NoSuchAlgorithmException error) {
      throw new IllegalStateException("计算媒体资源摘要失败", error);
    }
  }

  private String sha256(byte[] bytes) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(bytes));
    } catch (NoSuchAlgorithmException error) {
      throw new IllegalStateException("无法计算媒体指纹", error);
    }
  }

  private AssignmentMediaSyncDtos.Timeline remapTimeline(
      String sourceJson, List<AssignmentResourceEntity> currentImages) {
    try {
      AssignmentMediaSyncDtos.Timeline source =
          mapper.readValue(sourceJson, AssignmentMediaSyncDtos.Timeline.class);
      if (source.items().size() != currentImages.size()) return null;
      List<AssignmentMediaSyncDtos.Item> remapped = new ArrayList<>();
      for (int i = 0; i < source.items().size(); i++) {
        AssignmentMediaSyncDtos.Item sourceItem = source.items().get(i);
        remapped.add(new AssignmentMediaSyncDtos.Item(
            currentImages.get(i).id.toString(),
            sourceItem.startMs(), sourceItem.endMs(), sourceItem.confidence()));
      }
      return new AssignmentMediaSyncDtos.Timeline(
          source.version(), source.durationMs(), source.confidence(), remapped);
    } catch (JsonProcessingException error) {
      log.warn("media_sync reuse_parse_failed message={}", error.getMessage());
      return null;
    }
  }

  private String toJson(AssignmentMediaSyncDtos.Timeline timeline) {
    try {
      return mapper.writeValueAsString(timeline);
    } catch (JsonProcessingException error) {
      throw new IllegalStateException("序列化图文同步时间轴失败", error);
    }
  }

  private String truncate(String value, int maxLength) {
    if (value == null) return "";
    return value.length() <= maxLength ? value : value.substring(0, maxLength);
  }

  private String text(String value) {
    return value == null ? "" : value;
  }

  public record TimelineBuildResult(UUID audioResourceId, long audioDurationMs,
      double confidence, String timelineJson, String analysisModel, String transcriptionModel) {}
}
