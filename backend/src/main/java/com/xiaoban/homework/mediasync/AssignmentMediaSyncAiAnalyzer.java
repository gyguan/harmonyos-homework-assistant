package com.xiaoban.homework.mediasync;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.assignment.AssignmentResourceEntity;
import com.xiaoban.homework.assignment.AssignmentResourceRepository;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.storage.FileStorage;
import java.math.BigInteger;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

@Component
public class AssignmentMediaSyncAiAnalyzer {
  private static final Logger log = LoggerFactory.getLogger(AssignmentMediaSyncAiAnalyzer.class);

  private final AssignmentMediaSyncRepository syncs;
  private final AssignmentResourceRepository resources;
  private final MediaAssetService mediaAssets;
  private final FileStorage storage;
  private final AiProviderProperties properties;
  private final AudioTranscriptionClient transcription;
  private final ImageContentAnalyzer imageAnalyzer;
  private final MediaSyncAlignmentClient alignment;
  private final JsonMapper mapper;

  public AssignmentMediaSyncAiAnalyzer(
      AssignmentMediaSyncRepository syncs,
      AssignmentResourceRepository resources,
      MediaAssetService mediaAssets,
      FileStorage storage,
      AiProviderProperties properties,
      AudioTranscriptionClient transcription,
      ImageContentAnalyzer imageAnalyzer,
      MediaSyncAlignmentClient alignment,
      JsonMapper mapper) {
    this.syncs = syncs;
    this.resources = resources;
    this.mediaAssets = mediaAssets;
    this.storage = storage;
    this.properties = properties;
    this.transcription = transcription;
    this.imageAnalyzer = imageAnalyzer;
    this.alignment = alignment;
    this.mapper = mapper;
  }

  public boolean canAnalyze(UUID syncId) {
    if (!transcription.available() || !imageAnalyzer.available() || !alignment.available()) {
      return false;
    }
    AssignmentMediaSyncEntity sync = syncs.findById(syncId).orElse(null);
    if (sync == null) return false;
    long imageCount = resources
        .findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
            sync.familyId, sync.assignmentId)
        .stream()
        .filter(item -> "IMAGE".equals(item.resourceType))
        .count();
    if (imageCount <= 0 || imageCount > properties.getMediaSyncMaxAiImages()) {
      log.info("media_sync ai_skipped assignmentId={} imageCount={} maxAiImages={} reason=IMAGE_COUNT",
          sync.assignmentId, imageCount, properties.getMediaSyncMaxAiImages());
      return false;
    }
    return true;
  }

  public AssignmentMediaSyncService.TimelineBuildResult analyze(UUID syncId) {
    AssignmentMediaSyncEntity sync = syncs.findById(syncId)
        .orElseThrow(() -> new IllegalStateException("图文同步任务不存在"));
    List<AssignmentResourceEntity> all =
        resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
            sync.familyId, sync.assignmentId);
    AssignmentResourceEntity audio = firstAudio(all);
    List<AssignmentResourceEntity> images = orderedImages(all);
    if (audio == null || images.isEmpty()) throw new IllegalStateException("语音作业资料不完整");

    AudioTranscriptionClient.Transcript transcript =
        transcription.transcribe(resolve(sync.familyId, audio))
            .orElseThrow(() -> new IllegalStateException("语音转写失败"));
    log.info("media_sync transcription_completed assignmentId={} syncId={} segments={} durationMs={} model={}",
        sync.assignmentId, sync.id, transcript.segments().size(), transcript.durationMs(), transcript.model());

    List<ImageContentAnalyzer.Result> summaries = new ArrayList<>();
    List<MediaSyncAlignmentClient.ImageInput> alignmentImages = new ArrayList<>();
    for (int i = 0; i < images.size(); i++) {
      AssignmentResourceEntity image = images.get(i);
      ImageContentAnalyzer.Result result = imageAnalyzer
          .analyze(resolve(sync.familyId, image), image.contentType, image.originalName)
          .orElseThrow(() -> new IllegalStateException("第 " + (i + 1) + " 张图片分析失败"));
      summaries.add(result);
      alignmentImages.add(new MediaSyncAlignmentClient.ImageInput(i, result.summary()));
    }
    log.info("media_sync image_analysis_completed assignmentId={} syncId={} imageCount={} model={}",
        sync.assignmentId, sync.id, images.size(), summaries.get(0).model());

    MediaSyncAlignmentClient.Result aligned =
        alignment.align(transcript, alignmentImages)
            .orElseThrow(() -> new IllegalStateException("语音与图片语义对齐失败"));

    List<AssignmentMediaSyncDtos.Item> items = new ArrayList<>();
    for (MediaSyncAlignmentClient.Boundary boundary : aligned.boundaries()) {
      AssignmentResourceEntity image = images.get(boundary.imageIndex());
      items.add(new AssignmentMediaSyncDtos.Item(
          image.id.toString(),
          boundary.startMs(),
          boundary.endMs(),
          boundary.confidence()));
    }
    AssignmentMediaSyncDtos.Timeline timeline =
        new AssignmentMediaSyncDtos.Timeline(
            1, aligned.durationMs(), aligned.confidence(), List.copyOf(items));
    try {
      return new AssignmentMediaSyncService.TimelineBuildResult(
          audio.id,
          aligned.durationMs(),
          aligned.confidence(),
          mapper.writeValueAsString(timeline),
          compact(aligned.model(), 120),
          compact(transcript.model(), 120));
    } catch (Exception error) {
      throw new IllegalStateException("序列化AI图文同步时间轴失败", error);
    }
  }

  private Path resolve(UUID familyId, AssignmentResourceEntity resource) {
    if (resource.assetId != null) {
      return mediaAssets.resolveOwned(familyId, resource.assetId).path();
    }
    if (resource.storagePath == null || resource.storagePath.isBlank()) {
      throw new IllegalStateException("媒体文件路径为空");
    }
    return storage.resolve(resource.storagePath);
  }

  private AssignmentResourceEntity firstAudio(List<AssignmentResourceEntity> all) {
    for (AssignmentResourceEntity item : all) {
      if ("AUDIO".equals(item.resourceType)) return item;
    }
    return null;
  }

  private List<AssignmentResourceEntity> orderedImages(List<AssignmentResourceEntity> all) {
    return all.stream()
        .filter(item -> "IMAGE".equals(item.resourceType))
        .sorted(this::compareImages)
        .toList();
  }

  private int compareImages(AssignmentResourceEntity left, AssignmentResourceEntity right) {
    int byName = naturalCompare(
        text(left.originalName).toLowerCase(Locale.ROOT),
        text(right.originalName).toLowerCase(Locale.ROOT));
    if (byName != 0) return byName;
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
        int compare = new BigInteger(left.substring(li, le))
            .compareTo(new BigInteger(right.substring(ri, re)));
        if (compare != 0) return compare;
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

  private String compact(String value, int max) {
    if (value == null) return "";
    return value.length() <= max ? value : value.substring(0, max);
  }

  private String text(String value) {
    return value == null ? "" : value;
  }
}
